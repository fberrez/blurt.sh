# frozen_string_literal: true

module Publishers
  class BlueskyPublisher < Base
    GRAPHEME_LIMIT = 300
    DEFAULT_SERVICE = "https://bsky.social"

    def call(post, images)
      text = prepare_text(post)

      if text.length > GRAPHEME_LIMIT
        raise "Post exceeds Bluesky #{GRAPHEME_LIMIT}-char limit (#{text.length} chars)"
      end

      session = create_session
      facets = detect_facets(text, session)
      embedded_images = upload_images(images, session)
      link_embed = fetch_link_embed(facets, session) if embedded_images.nil?
      record = create_post(text, facets, embedded_images, link_embed, session)

      build_result(record, session)
    end

    private

    # --- Authentication ---

    def create_session
      conn = build_connection(service_url)
      resp = conn.post("/xrpc/com.atproto.server.createSession", {
        identifier: @config[:identifier],
        password: @config[:password]
      })
      resp.body
    end

    # --- Rich text facets (byte offsets, not character offsets) ---

    def detect_facets(text, session)
      facets = []
      facets.concat(detect_url_facets(text))
      facets.concat(detect_mention_facets(text, session))
      facets.concat(detect_hashtag_facets(text))
      facets
    end

    def detect_url_facets(text)
      facets = []

      # Full URLs (https://...)
      full_url_regex = %r{https?://[^\s)\]>]+}
      facets.concat(scan_with_byte_offsets(text, full_url_regex).map do |match_text, byte_start, byte_end|
        {
          index: { byteStart: byte_start, byteEnd: byte_end },
          features: [{ "$type" => "app.bsky.richtext.facet#link", uri: match_text }]
        }
      end)

      # Bare domains (e.g., blurt.sh, example.com/path)
      bare_domain_regex = /(?<![\/\w])([a-zA-Z0-9][-a-zA-Z0-9]*\.[a-zA-Z]{2,}(?:\/\S*)?)/
      scan_with_byte_offsets(text, bare_domain_regex).each do |match_text, byte_start, byte_end|
        next if match_text.start_with?("http")
        # Skip if this range overlaps with an already-detected full URL
        next if facets.any? { |f| byte_start >= f[:index][:byteStart] && byte_start < f[:index][:byteEnd] }

        facets << {
          index: { byteStart: byte_start, byteEnd: byte_end },
          features: [{ "$type" => "app.bsky.richtext.facet#link", uri: "https://#{match_text}" }]
        }
      end

      facets
    end

    def detect_mention_facets(text, session)
      # Match @handle where handle is a valid domain (e.g., @user.bsky.social)
      mention_regex = /(?<=^|(?<=\s))@([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+)/
      scan_with_byte_offsets(text, mention_regex).filter_map do |match_text, byte_start, byte_end|
        handle = match_text.delete_prefix("@")
        did = resolve_handle(handle, session)
        next unless did

        {
          index: { byteStart: byte_start, byteEnd: byte_end },
          features: [{ "$type" => "app.bsky.richtext.facet#mention", did: did }]
        }
      end
    end

    def detect_hashtag_facets(text)
      hashtag_regex = /(?<=^|(?<=\s))#([a-zA-Z\p{L}][a-zA-Z0-9\p{L}_]*)/
      scan_with_byte_offsets(text, hashtag_regex).map do |match_text, byte_start, byte_end|
        tag = match_text.delete_prefix("#")
        {
          index: { byteStart: byte_start, byteEnd: byte_end },
          features: [{ "$type" => "app.bsky.richtext.facet#tag", tag: tag }]
        }
      end
    end

    # Scans text for regex matches and returns [match_text, byte_start, byte_end].
    # Uses byte offsets (not character offsets) as required by AT Protocol.
    def scan_with_byte_offsets(text, regex)
      results = []
      text.scan(regex) do
        match = Regexp.last_match
        full_match = match[0]
        char_start = match.begin(0)
        byte_start = text[0...char_start].bytesize
        byte_end = byte_start + full_match.bytesize
        results << [full_match, byte_start, byte_end]
      end
      results
    end

    def resolve_handle(handle, session)
      conn = authed_connection(session)
      resp = conn.get("/xrpc/com.atproto.identity.resolveHandle", { handle: handle })
      resp.body["did"]
    rescue Faraday::Error
      nil
    end

    # --- Image upload ---

    def upload_images(images, session)
      return nil if images.empty?

      images.first(4).map do |image|
        conn = Faraday.new(url: service_url) do |f|
          f.request :authorization, "Bearer", session["accessJwt"]
          f.response :json, content_type: /\bjson$/
          f.response :raise_error
          f.adapter Faraday.default_adapter
        end

        resp = conn.post("/xrpc/com.atproto.repo.uploadBlob") do |req|
          req.headers["Content-Type"] = image[:mime_type]
          req.body = image[:io].read
        end

        { blob: resp.body["blob"], alt: image[:alt].to_s }
      end
    end

    # --- Link preview (external embed) ---

    def fetch_link_embed(facets, session)
      # Find first link facet URL
      link_facet = facets.find { |f| f[:features].any? { |feat| feat["$type"] == "app.bsky.richtext.facet#link" } }
      return nil unless link_facet

      uri = link_facet[:features].first[:uri]
      og = fetch_og_metadata(uri)
      return nil unless og[:title].present?

      embed = {
        "$type" => "app.bsky.embed.external",
        "external" => {
          "uri" => uri,
          "title" => og[:title].truncate(300),
          "description" => og[:description].to_s.truncate(1000)
        }
      }

      # Upload thumbnail if present
      if og[:image].present?
        thumb_blob = upload_og_image(og[:image], session)
        embed["external"]["thumb"] = thumb_blob if thumb_blob
      end

      embed
    rescue => e
      Rails.logger.warn "[blurt] [bluesky] Link preview failed: #{e.message}"
      nil
    end

    def fetch_og_metadata(url)
      resp = Faraday.get(url) do |req|
        req.headers["User-Agent"] = "BlurtBot/1.0"
        req.options.timeout = 5
        req.options.open_timeout = 3
      end

      html = resp.body.to_s
      {
        title: decode_entities(
          html[/<meta[^>]*property="og:title"[^>]*content="([^"]*)"/, 1] ||
          html[/<meta[^>]*content="([^"]*)"[^>]*property="og:title"/, 1] ||
          html[/<title>([^<]*)<\/title>/, 1]
        ),
        description: decode_entities(
          html[/<meta[^>]*property="og:description"[^>]*content="([^"]*)"/, 1] ||
          html[/<meta[^>]*content="([^"]*)"[^>]*property="og:description"/, 1]
        ),
        image: html[/<meta[^>]*property="og:image"[^>]*content="([^"]*)"/, 1] ||
               html[/<meta[^>]*content="([^"]*)"[^>]*property="og:image"/, 1]
      }
    rescue Faraday::Error
      {}
    end

    def upload_og_image(image_url, session)
      resp = Faraday.get(image_url) do |req|
        req.headers["User-Agent"] = "BlurtBot/1.0"
        req.options.timeout = 5
      end
      return nil unless resp.success?

      content_type = resp.headers["content-type"]&.split(";")&.first || "image/jpeg"

      conn = Faraday.new(url: service_url) do |f|
        f.request :authorization, "Bearer", session["accessJwt"]
        f.response :json, content_type: /\bjson$/
        f.response :raise_error
        f.adapter Faraday.default_adapter
      end

      blob_resp = conn.post("/xrpc/com.atproto.repo.uploadBlob") do |req|
        req.headers["Content-Type"] = content_type
        req.body = resp.body
      end

      blob_resp.body["blob"]
    rescue => e
      Rails.logger.warn "[blurt] [bluesky] Thumbnail upload failed: #{e.message}"
      nil
    end

    def decode_entities(text)
      return nil unless text
      CGI.unescapeHTML(text)
    end

    # --- Post creation ---

    def create_post(text, facets, embedded_images, link_embed, session)
      record = {
        "$type" => "app.bsky.feed.post",
        "text" => text,
        "createdAt" => Time.current.utc.iso8601(3)
      }

      record["facets"] = facets if facets.any?

      if embedded_images&.any?
        record["embed"] = {
          "$type" => "app.bsky.embed.images",
          "images" => embedded_images.map do |img|
            { "alt" => img[:alt], "image" => img[:blob] }
          end
        }
      elsif link_embed
        record["embed"] = link_embed
      end

      conn = authed_connection(session)
      resp = conn.post("/xrpc/com.atproto.repo.createRecord", {
        repo: session["did"],
        collection: "app.bsky.feed.post",
        record: record
      })
      resp.body
    end

    # --- Result ---

    def build_result(record, session)
      uri = record["uri"] # at://did:plc:xxx/app.bsky.feed.post/rkey
      rkey = uri.split("/").last
      did = session["did"]

      { url: "https://bsky.app/profile/#{did}/post/#{rkey}", published_at: Time.current }
    end

    # --- Helpers ---

    def authed_connection(session)
      build_connection(service_url, headers: {
        "Authorization" => "Bearer #{session['accessJwt']}"
      })
    end

    def service_url
      @config[:service] || DEFAULT_SERVICE
    end
  end
end
