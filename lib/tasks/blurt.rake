# frozen_string_literal: true

namespace :blurt do
  desc "Scan queue/ for pending posts and publish immediately"
  task scan: :environment do
    puts "[blurt] Scanning queue for pending posts..."
    posts = QueueScanner.pending_posts

    if posts.empty?
      puts "[blurt] No pending posts found."
      exit 0
    end

    puts "[blurt] Found #{posts.length} pending post(s):"
    posts.each { |p| puts "  - #{p.filename} -> #{p.platforms.join(', ')}" }
    puts

    posts.each do |post|
      locked_path = QueueScanner.lock!(post)
      unless locked_path
        puts "[blurt] Could not lock #{post.filename} -- already being processed"
        next
      end

      puts "[blurt] Publishing #{post.filename}..."
      begin
        results = PublishOrchestrator.publish(post, locked_path: locked_path)
        results.each do |platform, result|
          if result[:url]
            puts "  #{platform}: #{result[:url]}"
          elsif result[:error]
            puts "  #{platform}: FAILED -- #{result[:error]}"
          end
        end
      rescue => e
        puts "  Error: #{e.message}"
        QueueScanner.unlock!(locked_path, post.file_path) rescue nil
      end
    end

    puts "\n[blurt] Done."
  end

  desc "Show configured and unconfigured platforms"
  task platforms: :environment do
    puts "[blurt] Platform Configuration"
    puts "=" * 50
    puts

    BlurtConfig::PLATFORMS.each do |name|
      configured = BlurtConfig.platform_configured?(name)
      type = Post::BLOG_PLATFORMS.include?(name) ? "blog" : "social"
      status = configured ? "configured" : "not configured"
      puts "  %-12s %-8s %s" % [name, "(#{type})", status]
    end

    configured = BlurtConfig.configured_platforms
    puts
    puts "#{configured.length}/#{BlurtConfig::PLATFORMS.length} platforms configured."

    unless configured.length == BlurtConfig::PLATFORMS.length
      puts
      puts "Missing credentials? Check .env.example for required variables."
    end
  end

  desc "Re-authenticate LinkedIn OAuth (tokens expire every 60 days)"
  task linkedin_auth: :environment do
    require "webrick"
    require "securerandom"

    client_id = ENV["LINKEDIN_CLIENT_ID"]
    client_secret = ENV["LINKEDIN_CLIENT_SECRET"]

    unless client_id.present? && client_secret.present?
      puts "[blurt] ERROR: LINKEDIN_CLIENT_ID and LINKEDIN_CLIENT_SECRET must be set in .env"
      puts "  These are obtained from the LinkedIn Developer Portal:"
      puts "  https://www.linkedin.com/developers/apps"
      exit 1
    end

    callback_port = 8089
    redirect_uri = "http://localhost:#{callback_port}/callback"
    state = SecureRandom.hex(16)
    scopes = "openid profile w_member_social"

    auth_url = "https://www.linkedin.com/oauth/v2/authorization?" + URI.encode_www_form(
      response_type: "code",
      client_id: client_id,
      redirect_uri: redirect_uri,
      state: state,
      scope: scopes
    )

    code = nil
    server = WEBrick::HTTPServer.new(
      Port: callback_port,
      Logger: WEBrick::Log.new("/dev/null"),
      AccessLog: []
    )

    server.mount_proc "/callback" do |req, res|
      params = req.query
      if params["state"] != state
        res.body = "State mismatch. Please try again."
        res.status = 400
      elsif params["error"]
        res.body = "Authorization denied: #{params['error_description']}"
        res.status = 400
      else
        code = params["code"]
        res.body = "<html><body><h2>LinkedIn authorization successful!</h2><p>You can close this tab and return to the terminal.</p></body></html>"
        res.content_type = "text/html"
      end
      server.shutdown
    end

    puts "[blurt] LinkedIn OAuth Authentication"
    puts "=" * 50
    puts
    puts "Opening browser for LinkedIn authorization..."
    puts "If the browser doesn't open, visit this URL manually:"
    puts
    puts "  #{auth_url}"
    puts

    if RUBY_PLATFORM.include?("darwin")
      system("open", auth_url)
    elsif RUBY_PLATFORM.include?("linux")
      system("xdg-open", auth_url)
    end

    puts "Waiting for callback on http://localhost:#{callback_port}/callback ..."
    server.start

    unless code
      puts "[blurt] ERROR: No authorization code received."
      exit 1
    end

    puts "[blurt] Authorization code received. Exchanging for access token..."

    conn = Faraday.new(url: "https://www.linkedin.com") do |f|
      f.request :url_encoded
      f.response :json, content_type: /\bjson$/
      f.response :raise_error
      f.adapter Faraday.default_adapter
    end

    token_resp = conn.post("/oauth/v2/accessToken", {
      grant_type: "authorization_code",
      code: code,
      redirect_uri: redirect_uri,
      client_id: client_id,
      client_secret: client_secret
    })

    access_token = token_resp.body["access_token"]
    expires_in = token_resp.body["expires_in"]

    unless access_token
      puts "[blurt] ERROR: No access token in response: #{token_resp.body}"
      exit 1
    end

    api_conn = Faraday.new(url: "https://api.linkedin.com") do |f|
      f.response :json, content_type: /\bjson$/
      f.response :raise_error
      f.adapter Faraday.default_adapter
    end

    profile_resp = api_conn.get("/v2/userinfo") do |req|
      req.headers["Authorization"] = "Bearer #{access_token}"
    end

    person_id = profile_resp.body["sub"]

    puts
    puts "[blurt] Success! Update your .env with these values:"
    puts "=" * 50
    puts "LINKEDIN_ACCESS_TOKEN=#{access_token}"
    puts "LINKEDIN_PERSON_ID=#{person_id}"
    puts
    puts "Token expires in #{expires_in.to_i / 86400} days (#{Time.now + expires_in.to_i})."
    puts "Run this task again when it expires."
  rescue Faraday::Error => e
    puts "[blurt] ERROR: HTTP request failed: #{e.message}"
    exit 1
  rescue Interrupt
    puts "\n[blurt] Cancelled."
    server&.shutdown
    exit 1
  end
end
