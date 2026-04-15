# frozen_string_literal: true

module BlurtMcp
  module Tools
    module PublishNow
      def self.register(server, client)
        server.define_tool(
          name: "publish-now",
          description: "Force-publish a queued post immediately (bypasses schedule)",
          input_schema: {
            type: "object",
            properties: {
              id: { type: "string", description: "Post ID or filename" }
            },
            required: %w[id]
          }
        ) do |id:, server_context: nil|
          data = client.publish_post(id)
          results = data["results"] || []

          if results.empty?
            MCP::Tool::Response.new([{ type: "text", text: "Published #{id} (no per-platform results returned)." }])
          else
            lines = ["Published #{id}:", ""]
            results.each do |r|
              platform = r["platform"]
              if r["url"]
                lines << "- #{platform}: #{r['url']}"
              else
                lines << "- #{platform}: FAILED — #{r['error'] || 'unknown error'}"
              end
            end
            MCP::Tool::Response.new([{ type: "text", text: lines.join("\n") }])
          end
        rescue Blurt::Client::NotFoundError => e
          MCP::Tool::Response.new([{ type: "text", text: "Not found: #{id}. Use list-queue to see available posts." }], error: true)
        rescue Blurt::Client::Error => e
          MCP::Tool::Response.new([{ type: "text", text: "Error: #{e.message}" }], error: true)
        end
      end
    end
  end
end
