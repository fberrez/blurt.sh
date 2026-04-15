# frozen_string_literal: true

module BlurtMcp
  module Tools
    module GetPost
      def self.register(server, client)
        server.define_tool(
          name: "get-post",
          description: "Fetch a single post by ID or filename",
          input_schema: {
            type: "object",
            properties: {
              id: { type: "string", description: "Post ID or filename" }
            },
            required: %w[id]
          }
        ) do |id:, server_context: nil|
          data = client.get_post(id)
          post = data["post"] || data

          lines = ["Post: #{post['filename'] || id}"]
          lines << "  Status: #{post['status']}" if post["status"]
          lines << "  Platforms: #{Array(post['platforms']).join(', ')}" if post["platforms"]
          lines << "  Scheduled: #{post['scheduled_at']}" if post["scheduled_at"]
          lines << "  Published: #{post['published_at']}" if post["published_at"]
          if post["content"]
            lines << ""
            lines << "---"
            lines << post["content"]
          end

          MCP::Tool::Response.new([{ type: "text", text: lines.join("\n") }])
        rescue Blurt::Client::NotFoundError => e
          MCP::Tool::Response.new([{ type: "text", text: "Not found: #{id}. Use list-queue to see available posts." }], error: true)
        rescue Blurt::Client::Error => e
          MCP::Tool::Response.new([{ type: "text", text: "Error: #{e.message}" }], error: true)
        end
      end
    end
  end
end
