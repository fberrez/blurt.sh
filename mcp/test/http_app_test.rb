# frozen_string_literal: true

require "test_helper"
require "blurt_mcp/http_app"
require "json"
require "rack/mock"

class HttpAppTest < Minitest::Test
  def setup
    config = Blurt::Config.new(api_url: "http://localhost:3000", api_key: "test-key")
    @app = BlurtMcp::HttpApp.new(config: config, stateless: true)
    @mock = Rack::MockRequest.new(@app)
  end

  def test_unknown_path_returns_404
    response = @mock.post("/nope", input: "{}", "CONTENT_TYPE" => "application/json")
    assert_equal 404, response.status
  end

  def test_initialize_and_tools_list_over_http
    body = {
      jsonrpc: "2.0", id: "init", method: "initialize",
      params: { protocolVersion: "2025-03-26", capabilities: {}, clientInfo: { name: "t", version: "1" } }
    }.to_json
    headers = { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json, text/event-stream" }
    init = @mock.post("/mcp", input: body, **headers)
    assert_equal 200, init.status

    body = {
      jsonrpc: "2.0", id: "list", method: "tools/list", params: {}
    }.to_json
    list = @mock.post("/mcp", input: body, **headers)
    assert_equal 200, list.status
    parsed = JSON.parse(list.body)
    names = parsed.dig("result", "tools").map { |t| t["name"] }.sort
    expected = %w[create-post delete-post get-platforms get-post list-history list-queue publish-now]
    assert_equal expected, names
  end

  def test_resources_list_over_http
    headers = {
      "CONTENT_TYPE" => "application/json",
      "HTTP_ACCEPT" => "application/json, text/event-stream"
    }

    init_body = {
      jsonrpc: "2.0", id: "init", method: "initialize",
      params: { protocolVersion: "2025-03-26", capabilities: {}, clientInfo: { name: "t", version: "1" } }
    }.to_json
    @mock.post("/mcp", input: init_body, **headers)

    body = {
      jsonrpc: "2.0", id: "rl", method: "resources/list", params: {}
    }.to_json
    resp = @mock.post("/mcp", input: body, **headers)
    assert_equal 200, resp.status
    parsed = JSON.parse(resp.body)
    uris = parsed.dig("result", "resources").map { |r| r["uri"] }.sort
    assert_equal %w[blurt://platforms blurt://queue], uris
  end
end
