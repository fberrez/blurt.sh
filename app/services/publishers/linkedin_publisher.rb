# frozen_string_literal: true

module Publishers
  class LinkedinPublisher < Base
    API_BASE = "https://api.linkedin.com"
    API_VERSION = "202602"

    def call(post, images)
      text = prepare_text(post)
      image_urns = upload_images(images)
      response = create_post(text, image_urns)
      build_result(response)
    rescue Faraday::UnauthorizedError => e
      raise "LinkedIn token expired (401). Tokens expire every 60 days. " \
            "Re-authenticate via rake blurt:linkedin_auth — #{e.message}"
    end

    private

    def upload_images(images)
      return [] if images.empty?

      images.first(4).map do |image|
        # Step 1: Initialize upload
        init_resp = connection.post("/rest/images?action=initializeUpload", {
          initializeUploadRequest: { owner: author_urn }
        })

        upload_url = init_resp.body.dig("value", "uploadUrl")
        image_urn = init_resp.body.dig("value", "image")

        # Step 2: PUT binary to upload URL (external host, separate connection)
        upload_conn = Faraday.new do |f|
          f.response :raise_error
          f.adapter Faraday.default_adapter
          f.options.timeout = 30
          f.options.open_timeout = 5
        end

        upload_conn.put(upload_url) do |req|
          req.headers["Authorization"] = "Bearer #{@config[:access_token]}"
          req.headers["Content-Type"] = image[:mime_type]
          req.body = image[:io].read
        end

        image_urn
      end
    end

    def create_post(text, image_urns)
      body = {
        author: author_urn,
        commentary: text,
        visibility: "PUBLIC",
        distribution: {
          feedDistribution: "MAIN_FEED",
          targetEntities: [],
          thirdPartyDistributionChannels: []
        },
        lifecycleState: "PUBLISHED",
        isReshareDisabledByAuthor: false
      }

      if image_urns.length == 1
        body[:content] = { media: { id: image_urns.first } }
      elsif image_urns.length > 1
        body[:content] = {
          multiImage: { images: image_urns.map { |urn| { id: urn } } }
        }
      else
        # No images — attach first URL as link preview with thumbnail
        link_url = extract_first_url(text)
        if link_url
          og = fetch_og_metadata(link_url)
          article = { source: link_url }
          article[:title] = og[:title] if og[:title].present?
          article[:description] = og[:description] if og[:description].present?

          if og[:image].present?
            thumb_urn = upload_og_thumbnail(og[:image])
            article[:thumbnail] = thumb_urn if thumb_urn
          end

          body[:content] = { article: article }
        end
      end

      connection.post("/rest/posts", body)
    end

    def build_result(response)
      post_id = response.headers["x-restli-id"]
      url = post_id ? "https://www.linkedin.com/feed/update/#{post_id}" : nil

      { url: url, published_at: Time.current }
    end

    def connection
      @connection ||= build_connection(API_BASE, headers: {
        "Authorization" => "Bearer #{@config[:access_token]}",
        "X-Restli-Protocol-Version" => "2.0.0",
        "LinkedIn-Version" => API_VERSION
      })
    end

    def extract_first_url(text)
      # Match full URLs first, then bare domains
      match = text.match(%r{https?://[^\s)\]>]+}) ||
              text.match(/(?<![\/\w])([a-zA-Z0-9][-a-zA-Z0-9]*\.[a-zA-Z]{2,}(?:\/\S*)?)/)
      return nil unless match

      url = match[1] || match[0]
      url.start_with?("http") ? url : "https://#{url}"
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

    def upload_og_thumbnail(image_url)
      # Download the OG image
      resp = Faraday.get(image_url) do |req|
        req.headers["User-Agent"] = "BlurtBot/1.0"
        req.options.timeout = 5
      end
      return nil unless resp.success?

      content_type = resp.headers["content-type"]&.split(";")&.first || "image/png"

      # Upload via LinkedIn's two-step image upload
      init_resp = connection.post("/rest/images?action=initializeUpload", {
        initializeUploadRequest: { owner: author_urn }
      })

      upload_url = init_resp.body.dig("value", "uploadUrl")
      image_urn = init_resp.body.dig("value", "image")

      upload_conn = Faraday.new do |f|
        f.response :raise_error
        f.adapter Faraday.default_adapter
        f.options.timeout = 30
        f.options.open_timeout = 5
      end

      upload_conn.put(upload_url) do |req|
        req.headers["Authorization"] = "Bearer #{@config[:access_token]}"
        req.headers["Content-Type"] = content_type
        req.body = resp.body
      end

      image_urn
    rescue => e
      Rails.logger.warn "[blurt] [linkedin] Thumbnail upload failed: #{e.message}"
      nil
    end

    def decode_entities(text)
      return nil unless text
      CGI.unescapeHTML(text)
    end

    def author_urn
      "urn:li:person:#{@config[:person_id]}"
    end
  end
end
