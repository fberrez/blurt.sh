# frozen_string_literal: true

module BlurtMcp
  module Tools
    module ListQueue
      def self.register(server, client)
        server.define_tool(
          name: "list-queue",
          description: "List posts in the publishing queue",
          input_schema: {
            type: "object",
            properties: {
              status: {
                type: "string",
                enum: %w[queue sent failed all],
                description: "Filter by status (default: queue)"
              },
              platform: { type: "string", description: "Filter by platform" }
            }
          }
        ) do |status: "queue", platform: nil, server_context: nil|
          data = client.list_posts(status: status, platform: platform)
          posts = data["posts"]

          if posts.empty?
            MCP::Tool::Response.new([{ type: "text", text: "No #{status} posts found." }])
          else
            lines = ["#{posts.length} post(s):", ""]
            posts.each do |post|
              scheduled = post["scheduled_at"] || "immediate"
              lines << "- #{post['filename']} [#{Array(post['platforms']).join(', ')}] (#{post['status']}, #{scheduled})"
            end
            MCP::Tool::Response.new([{ type: "text", text: lines.join("\n") }])
          end
        rescue Blurt::Client::Error => e
          MCP::Tool::Response.new([{ type: "text", text: "Error: #{e.message}" }], error: true)
        end
      end
    end
  end
end
