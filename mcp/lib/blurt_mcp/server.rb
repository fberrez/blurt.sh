# frozen_string_literal: true

require_relative "tools/create_post"
require_relative "tools/list_queue"
require_relative "tools/get_platforms"
require_relative "tools/list_history"
require_relative "tools/publish_now"
require_relative "tools/get_post"
require_relative "tools/delete_post"
require_relative "resources/queue"
require_relative "resources/platforms"

module BlurtMcp
  module Server
    TOOLS = [
      Tools::CreatePost,
      Tools::ListQueue,
      Tools::GetPlatforms,
      Tools::ListHistory,
      Tools::PublishNow,
      Tools::GetPost,
      Tools::DeletePost
    ].freeze

    RESOURCES = [
      Resources::Queue,
      Resources::Platforms
    ].freeze

    def self.build(config)
      client = Blurt::Client.new(config)

      server = MCP::Server.new(
        name: "blurt",
        version: Blurt::VERSION,
        resources: RESOURCES.map(&:descriptor)
      )

      TOOLS.each { |tool| tool.register(server, client) }

      server.resources_read_handler do |params|
        uri = params[:uri] || params["uri"]
        handler = RESOURCES.find { |r| r.descriptor.uri == uri }
        raise MCP::Server::RequestHandlerError.new("Unknown resource: #{uri}", params, error_type: :invalid_params) unless handler

        handler.read(client).map(&:to_h)
      end

      server
    end
  end
end
