# frozen_string_literal: true

module Publishers
  class MediumPublisher < Base
    API_BASE = "https://api.medium.com"

    def call(post, _images)
      log("Publishing '#{post.title}' to Medium")

      user_id = fetch_user_id
      html_content = MarkdownProcessor.to_html(post.content)
      response = create_post(user_id, post.title, html_content)

      { url: response.dig("data", "url"), published_at: Time.current }
    end

    private

    def fetch_user_id
      resp = connection.get("/v1/me")
      resp.body.dig("data", "id")
    end

    def create_post(user_id, title, html_content)
      resp = connection.post("/v1/users/#{user_id}/posts", {
        title: title,
        contentFormat: "html",
        content: html_content,
        publishStatus: "public"
      })
      resp.body
    end

    def connection
      @connection ||= build_connection(API_BASE, headers: {
        "Authorization" => "Bearer #{@config[:integration_token]}"
      })
    end
  end
end
