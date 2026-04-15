# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
$LOAD_PATH.unshift File.expand_path("../../cli/lib", __dir__)

require "blurt_mcp"
require "minitest/autorun"
require "webmock/minitest"
require "securerandom"

WebMock.disable_net_connect!

module McpTestHelpers
  def build_server(api_url: "http://localhost:3000", api_key: "test-key")
    config = Blurt::Config.new(api_url: api_url, api_key: api_key)
    server = BlurtMcp::Server.build(config)
    initialize_server!(server)
    server
  end

  def initialize_server!(server)
    request = {
      jsonrpc: "2.0", id: "init", method: "initialize",
      params: {
        protocolVersion: "2025-03-26",
        capabilities: {},
        clientInfo: { name: "test", version: "1.0" }
      }
    }.to_json
    server.handle_json(request)
  end

  def call_tool(server, name, arguments)
    request = {
      jsonrpc: "2.0", id: SecureRandom.uuid, method: "tools/call",
      params: { name: name, arguments: arguments }
    }.to_json
    response = JSON.parse(server.handle_json(request))
    response["result"]
  end

  def read_resource(server, uri)
    request = {
      jsonrpc: "2.0", id: SecureRandom.uuid, method: "resources/read",
      params: { uri: uri }
    }.to_json
    response = JSON.parse(server.handle_json(request))
    response["result"]
  end

  def list_resources(server)
    request = {
      jsonrpc: "2.0", id: SecureRandom.uuid, method: "resources/list",
      params: {}
    }.to_json
    response = JSON.parse(server.handle_json(request))
    response["result"]
  end

  def json_headers
    { "Content-Type" => "application/json" }
  end
end

class Minitest::Test
  include McpTestHelpers
end
