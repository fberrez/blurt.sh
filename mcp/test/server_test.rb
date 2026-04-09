# frozen_string_literal: true

require "test_helper"
require "json"

class ServerTest < Minitest::Test
  def setup
    @config = Blurt::Config.new(api_url: "http://localhost:3000", api_key: "test-key")
    @server = BlurtMcp::Server.build(@config)
    initialize_server!
  end

  # --- Server setup ---

  def test_server_has_correct_name
    assert_equal "blurt", @server.name
  end

  def test_server_has_correct_version
    assert_equal Blurt::VERSION, @server.version
  end

  def test_server_has_three_tools
    assert_equal 3, @server.tools.length
  end

  def test_server_tool_names
    names = @server.tools.keys.sort
    assert_equal %w[create-post get-platforms list-queue], names
  end

  # --- create-post ---

  def test_create_post_success
    stub_request(:post, "http://localhost:3000/api/posts")
      .to_return(status: 201, body: {
        post: {
          filename: "20260407-hello.md",
          platforms: %w[bluesky mastodon],
          status: "queue"
        }
      }.to_json, headers: json_headers)

    result = call_tool("create-post", {
      content: "Hello world!",
      platforms: %w[bluesky mastodon]
    })

    assert_equal false, result["isError"]
    text = result["content"].first["text"]
    assert_includes text, "Post created: 20260407-hello.md"
    assert_includes text, "bluesky, mastodon"
    assert_includes text, "Status: queue"
  end

  def test_create_post_with_title_and_schedule
    stub_request(:post, "http://localhost:3000/api/posts")
      .to_return(status: 201, body: {
        post: {
          filename: "20260407-my-article.md",
          platforms: %w[devto],
          status: "queue",
          scheduled_at: "2026-04-08T09:00:00Z"
        }
      }.to_json, headers: json_headers)

    result = call_tool("create-post", {
      content: "Long article",
      platforms: %w[devto],
      title: "My Article",
      scheduled_at: "2026-04-08T09:00:00Z"
    })

    text = result["content"].first["text"]
    assert_includes text, "Scheduled: 2026-04-08T09:00:00Z"
  end

  def test_create_post_auth_error
    stub_request(:post, "http://localhost:3000/api/posts")
      .to_return(status: 401, body: { error: "Unauthorized" }.to_json, headers: json_headers)

    result = call_tool("create-post", {
      content: "Hello",
      platforms: %w[bluesky]
    })

    assert_equal true, result["isError"]
    assert_includes result["content"].first["text"], "Error:"
  end

  # --- list-queue ---

  def test_list_queue_with_posts
    stub_request(:get, "http://localhost:3000/api/posts")
      .with(query: { status: "queue" })
      .to_return(status: 200, body: {
        posts: [
          { filename: "hello.md", platforms: %w[bluesky], status: "queue", scheduled_at: nil },
          { filename: "world.md", platforms: %w[mastodon linkedin], status: "queue", scheduled_at: "2026-04-08T09:00:00Z" }
        ]
      }.to_json, headers: json_headers)

    result = call_tool("list-queue", {})

    assert_equal false, result["isError"]
    text = result["content"].first["text"]
    assert_includes text, "2 post(s):"
    assert_includes text, "hello.md"
    assert_includes text, "world.md"
  end

  def test_list_queue_empty
    stub_request(:get, "http://localhost:3000/api/posts")
      .with(query: { status: "queue" })
      .to_return(status: 200, body: { posts: [] }.to_json, headers: json_headers)

    result = call_tool("list-queue", {})

    assert_includes result["content"].first["text"], "No queue posts found."
  end

  def test_list_queue_with_filters
    stub_request(:get, "http://localhost:3000/api/posts")
      .with(query: { status: "sent", platform: "bluesky" })
      .to_return(status: 200, body: { posts: [] }.to_json, headers: json_headers)

    result = call_tool("list-queue", { status: "sent", platform: "bluesky" })

    assert_includes result["content"].first["text"], "No sent posts found."
  end

  def test_list_queue_connection_error
    stub_request(:get, "http://localhost:3000/api/posts")
      .with(query: { status: "queue" })
      .to_raise(Faraday::ConnectionFailed.new("Connection refused"))

    result = call_tool("list-queue", {})

    assert_equal true, result["isError"]
    assert_includes result["content"].first["text"], "Error:"
  end

  # --- get-platforms ---

  def test_get_platforms_success
    stub_request(:get, "http://localhost:3000/api/platforms")
      .to_return(status: 200, body: {
        platforms: [
          { name: "bluesky", type: "social" },
          { name: "mastodon", type: "social" },
          { name: "devto", type: "blog" }
        ]
      }.to_json, headers: json_headers)

    result = call_tool("get-platforms", {})

    assert_equal false, result["isError"]
    text = result["content"].first["text"]
    assert_includes text, "3 platform(s) configured:"
    assert_includes text, "bluesky (social)"
    assert_includes text, "devto (blog)"
  end

  def test_get_platforms_empty
    stub_request(:get, "http://localhost:3000/api/platforms")
      .to_return(status: 200, body: { platforms: [] }.to_json, headers: json_headers)

    result = call_tool("get-platforms", {})

    assert_includes result["content"].first["text"], "No platforms configured."
  end

  def test_get_platforms_auth_error
    stub_request(:get, "http://localhost:3000/api/platforms")
      .to_return(status: 401, body: { error: "Unauthorized" }.to_json, headers: json_headers)

    result = call_tool("get-platforms", {})

    assert_equal true, result["isError"]
    assert_includes result["content"].first["text"], "Error:"
  end

  private

  def initialize_server!
    request = {
      jsonrpc: "2.0", id: "init", method: "initialize",
      params: {
        protocolVersion: "2025-03-26",
        capabilities: {},
        clientInfo: { name: "test", version: "1.0" }
      }
    }.to_json
    @server.handle_json(request)
  end

  def call_tool(name, arguments)
    request = {
      jsonrpc: "2.0", id: SecureRandom.uuid, method: "tools/call",
      params: { name: name, arguments: arguments }
    }.to_json
    response = JSON.parse(@server.handle_json(request))
    response["result"]
  end

  def json_headers
    { "Content-Type" => "application/json" }
  end
end
