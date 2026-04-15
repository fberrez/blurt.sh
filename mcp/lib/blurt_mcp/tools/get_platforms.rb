# frozen_string_literal: true

module BlurtMcp
  module Tools
    module GetPlatforms
      def self.register(server, client)
        server.define_tool(
          name: "get-platforms",
          description: "Show configured publishing platforms",
          input_schema: {
            type: "object",
            properties: {}
          }
        ) do |server_context: nil, **|
          data = client.platforms
          platforms = data["platforms"]

          if platforms.empty?
            MCP::Tool::Response.new([{ type: "text", text: "No platforms configured." }])
          else
            lines = ["#{platforms.length} platform(s) configured:", ""]
            platforms.each do |p|
              lines << "- #{p['name']} (#{p['type']})"
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
