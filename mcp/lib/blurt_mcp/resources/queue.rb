# frozen_string_literal: true

module BlurtMcp
  module Resources
    module Queue
      URI = "blurt://queue"
      MIME_TYPE = "application/json"

      def self.descriptor
        @descriptor ||= MCP::Resource.new(
          uri: URI,
          name: "queue",
          title: "Blurt queue",
          description: "Posts currently pending publication",
          mime_type: MIME_TYPE
        )
      end

      def self.read(client)
        data = client.list_posts(status: "queue")
        posts = data["posts"] || []

        payload = {
          count: posts.length,
          posts: posts.map do |p|
            {
              filename: p["filename"],
              platforms: p["platforms"],
              scheduled_at: p["scheduled_at"],
              status: p["status"]
            }
          end
        }

        [
          MCP::Resource::TextContents.new(
            uri: URI,
            mime_type: MIME_TYPE,
            text: JSON.pretty_generate(payload)
          )
        ]
      rescue Blurt::Client::Error => e
        [
          MCP::Resource::TextContents.new(
            uri: URI,
            mime_type: MIME_TYPE,
            text: JSON.pretty_generate(error: e.message)
          )
        ]
      end
    end
  end
end
