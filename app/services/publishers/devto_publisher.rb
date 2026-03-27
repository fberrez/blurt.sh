# frozen_string_literal: true

module Publishers
  class DevtoPublisher < Base
    API_BASE = "https://dev.to"

    def call(post, _images)
      log("Publishing '#{post.title}' to Dev.to")

      resp = connection.post("/api/articles", {
        article: {
          title: post.title,
          body_markdown: post.content,
          published: true
        }
      })

      { url: resp.body["url"], published_at: Time.current }
    end

    private

    def connection
      @connection ||= build_connection(API_BASE, headers: {
        "api-key" => @config[:api_key]
      })
    end
  end
end
