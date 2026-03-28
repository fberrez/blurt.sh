# frozen_string_literal: true

module Publishers
  class MastodonPublisher < Base
    CHARACTER_LIMIT = 500

    def call(post, images)
      text = prepare_text(post)

      if text.length > CHARACTER_LIMIT
        raise "Post exceeds Mastodon #{CHARACTER_LIMIT}-char limit (#{text.length} chars)"
      end

      text = linkify_bare_domains(text)
      media_ids = upload_images(images)
      status = create_status(text, media_ids)

      { url: status["url"], published_at: Time.current }
    end

    private

    # Mastodon auto-links full URLs but not bare domains.
    # Prepend https:// so they become clickable.
    def linkify_bare_domains(text)
      text.gsub(/(?<![\/\w])([a-zA-Z0-9][-a-zA-Z0-9]*\.[a-zA-Z]{2,}(?:\/\S*)?)/) do |match|
        match.start_with?("http") ? match : "https://#{match}"
      end
    end

    def upload_images(images)
      return [] if images.empty?

      images.first(4).map do |image|
        io = Faraday::Multipart::FilePart.new(
          image[:io],
          image[:mime_type],
          image[:filename]
        )
        params = { file: io }
        params[:description] = image[:alt] if image[:alt].present?

        resp = media_connection.post("/api/v2/media", params)
        resp.body["id"]
      end
    end

    def create_status(text, media_ids)
      params = { status: text }
      params[:media_ids] = media_ids if media_ids.any?

      resp = connection.post("/api/v1/statuses", params)
      resp.body
    end

    def connection
      @connection ||= build_connection(@config[:url], headers: {
        "Authorization" => "Bearer #{@config[:access_token]}"
      })
    end

    # Separate connection for multipart media uploads
    def media_connection
      @media_connection ||= Faraday.new(url: @config[:url]) do |f|
        f.request :multipart
        f.request :authorization, "Bearer", @config[:access_token]
        f.response :json, content_type: /\bjson$/
        f.response :raise_error
        f.adapter Faraday.default_adapter
        f.options.timeout = 30
        f.options.open_timeout = 5
      end
    end
  end
end
