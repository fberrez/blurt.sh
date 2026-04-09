# frozen_string_literal: true

module BlurtMcp
  module Server
    def self.build(config)
      client = Blurt::Client.new(config)

      server = MCP::Server.new(
        name: "blurt",
        version: Blurt::VERSION
      )

      register_create_post(server, client)
      register_list_queue(server, client)
      register_get_platforms(server, client)

      server
    end

    class << self
      private

      def register_create_post(server, client)
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

      def register_list_queue(server, client)
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

      def register_get_platforms(server, client)
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
