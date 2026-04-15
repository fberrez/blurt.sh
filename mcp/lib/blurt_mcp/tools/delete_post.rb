# frozen_string_literal: true

module BlurtMcp
  module Tools
    module DeletePost
      def self.register(server, client)
        server.define_tool(
          name: "delete-post",
          description: "Delete a queued post",
          input_schema: {
            type: "object",
            properties: {
              id: { type: "string", description: "Post ID or filename" }
            },
            required: %w[id]
          }
        ) do |id:, server_context: nil|
          client.delete_post(id)
          MCP::Tool::Response.new([{ type: "text", text: "Deleted #{id}." }])
        rescue Blurt::Client::NotFoundError => e
          MCP::Tool::Response.new([{ type: "text", text: "Not found: #{id}. Use list-queue to see available posts." }], error: true)
        rescue Blurt::Client::Error => e
          MCP::Tool::Response.new([{ type: "text", text: "Error: #{e.message}" }], error: true)
        end
      end
    end
  end
end
