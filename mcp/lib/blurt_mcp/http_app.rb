# frozen_string_literal: true

require "rack"
require "mcp/server/transports/streamable_http_transport"

module BlurtMcp
  # Minimal Rack app that exposes the MCP server over the MCP Streamable HTTP
  # transport at a single mount path (default: "/mcp"). Anything else 404s.
  #
  # Usage:
  #   app = BlurtMcp::HttpApp.new(config: Blurt::Config.new, stateless: true)
  #   # then mount with `run app` in a config.ru, or hand to Puma / WEBrick / etc.
  class HttpApp
    DEFAULT_PATH = "/mcp"

    def initialize(config:, path: DEFAULT_PATH, stateless: true)
      @path = path
      @server = BlurtMcp::Server.build(config)
      @transport = MCP::Server::Transports::StreamableHTTPTransport.new(@server, stateless: stateless)
      @server.transport = @transport
    end

    def call(env)
      request = Rack::Request.new(env)
      return not_found unless request.path == @path

      @transport.handle_request(request)
    end

    private

    def not_found
      [404, { "Content-Type" => "application/json" }, [{ error: "Not found. MCP endpoint is at #{@path}" }.to_json]]
    end
  end
end
