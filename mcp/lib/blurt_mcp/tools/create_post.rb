# frozen_string_literal: true

module BlurtMcp
  module Tools
    module CreatePost
      def self.register(server, client)
        server.define_tool(
          name: "create-post",
          description: "Create and queue a new post for publishing",
          input_schema: {
            type: "object",
            properties: {
              content: { type: "string", description: "Post content (markdown)" },
              platforms: {
                type: "array",
                items: { type: "string", enum: %w[bluesky mastodon linkedin medium devto substack] },
                description: "Target platforms"
              },
              title: { type: "string", description: "Post title (required for blog platforms)" },
              scheduled_at: { type: "string", description: "ISO 8601 publish time (omit for immediate)" }
            },
            required: %w[content platforms]
          }
        ) do |content:, platforms:, title: nil, scheduled_at: nil, server_context: nil|
          data = client.create_post(
            content: content,
            platforms: platforms,
            title: title,
            scheduled_at: scheduled_at
          )

          post = data["post"]
          lines = [
            "Post created: #{post['filename']}",
            "  Platforms: #{Array(post['platforms']).join(', ')}",
            "  Status: #{post['status']}"
          ]
          lines << "  Scheduled: #{post['scheduled_at']}" if post["scheduled_at"]

          MCP::Tool::Response.new([{ type: "text", text: lines.join("\n") }])
        rescue Blurt::Client::Error => e
          MCP::Tool::Response.new([{ type: "text", text: "Error: #{e.message}" }], error: true)
        end
      end
    end
  end
end
