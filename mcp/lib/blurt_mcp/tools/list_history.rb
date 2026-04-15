# frozen_string_literal: true

module BlurtMcp
  module Tools
    module ListHistory
      def self.register(server, client)
        server.define_tool(
          name: "list-history",
          description: "List published posts (the system of record)",
          input_schema: {
            type: "object",
            properties: {
              page: { type: "integer", description: "Page number (default: 1)" },
              per_page: { type: "integer", description: "Results per page" },
              platform: { type: "string", description: "Filter by platform" }
            }
          }
        ) do |page: nil, per_page: nil, platform: nil, server_context: nil|
          data = client.history(page: page, per_page: per_page, platform: platform)
          posts = data["posts"] || []

          if posts.empty?
            MCP::Tool::Response.new([{ type: "text", text: "No published posts found." }])
          else
            lines = ["#{posts.length} published post(s):", ""]
            posts.each do |post|
              platforms = Array(post["platforms"]).join(", ")
              published = post["published_at"] || post["scheduled_at"] || "unknown"
              urls = Array(post["urls"])
              url_summary =
                case urls.length
                when 0 then ""
                when 1 then " — #{urls.first}"
                else " — #{urls.first} (+#{urls.length - 1} more)"
                end
              lines << "- #{post['filename']} [#{platforms}] #{published}#{url_summary}"
            end
            if data["pagination"]
              pg = data["pagination"]
              lines << ""
              lines << "Page #{pg['page']} of #{pg['total_pages']} (#{pg['total']} total)"
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
