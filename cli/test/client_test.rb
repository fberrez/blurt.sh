# frozen_string_literal: true

require "test_helper"

class ClientTest < Minitest::Test
  def setup
    @config = Blurt::Config.new(api_url: "http://localhost:3000", api_key: "test-key")
    @client = Blurt::Client.new(@config)
  end

  # --- health ---

  def test_health_calls_correct_endpoint
    stub_request(:get, "http://localhost:3000/api/health")
      .to_return(status: 200, body: { status: "ok" }.to_json, headers: json_headers)

    result = @client.health
    assert_equal "ok", result["status"]
    assert_requested(:get, "http://localhost:3000/api/health")
  end

  def test_health_does_not_send_auth_header
    stub_request(:get, "http://localhost:3000/api/health")
      .to_return(status: 200, body: { status: "ok" }.to_json, headers: json_headers)

    @client.health
    assert_requested(:get, "http://localhost:3000/api/health") do |req|
      refute req.headers.key?("Authorization")
    end
  end

  # --- list_posts ---

  def test_list_posts_with_defaults
    stub_request(:get, "http://localhost:3000/api/posts")
      .to_return(status: 200, body: { posts: [] }.to_json, headers: json_headers)

    result = @client.list_posts
    assert_equal [], result["posts"]
  end

  def test_list_posts_with_filters
    stub_request(:get, "http://localhost:3000/api/posts")
      .with(query: { status: "sent", platform: "bluesky" })
      .to_return(status: 200, body: { posts: [ { id: "test.md" } ] }.to_json, headers: json_headers)

    result = @client.list_posts(status: "sent", platform: "bluesky")
    assert_equal 1, result["posts"].length
  end

  def test_list_posts_sends_auth_header
    stub_request(:get, "http://localhost:3000/api/posts")
      .to_return(status: 200, body: { posts: [] }.to_json, headers: json_headers)

    @client.list_posts
    assert_requested(:get, "http://localhost:3000/api/posts",
      headers: { "Authorization" => "Bearer test-key" })
  end

  # --- get_post ---

  def test_get_post_encodes_filename
    stub_request(:get, "http://localhost:3000/api/posts/my-post.md")
      .to_return(status: 200, body: { post: { id: "my-post.md" } }.to_json, headers: json_headers)

    result = @client.get_post("my-post.md")
    assert_equal "my-post.md", result["post"]["id"]
  end

  # --- create_post ---

  def test_create_post_sends_correct_body
    stub_request(:post, "http://localhost:3000/api/posts")
      .to_return(status: 201, body: { post: { id: "test.md" } }.to_json, headers: json_headers)

    @client.create_post(content: "Hello", platforms: %w[bluesky mastodon])

    assert_requested(:post, "http://localhost:3000/api/posts") do |req|
      body = JSON.parse(req.body)
      body["content"] == "Hello" && body["platforms"] == %w[bluesky mastodon]
    end
  end

  def test_create_post_with_optional_fields
    stub_request(:post, "http://localhost:3000/api/posts")
      .to_return(status: 201, body: { post: { id: "titled.md" } }.to_json, headers: json_headers)

    @client.create_post(
      content: "Hello",
      platforms: %w[devto],
      title: "My Article",
      filename: "titled.md",
      scheduled_at: "2026-04-01T09:00:00Z"
    )

    assert_requested(:post, "http://localhost:3000/api/posts") do |req|
      body = JSON.parse(req.body)
      body["title"] == "My Article" &&
        body["filename"] == "titled.md" &&
        body["scheduled_at"] == "2026-04-01T09:00:00Z"
    end
  end

  # --- update_post ---

  def test_update_post
    stub_request(:put, "http://localhost:3000/api/posts/test.md")
      .to_return(status: 200, body: { post: { id: "test.md" } }.to_json, headers: json_headers)

    @client.update_post("test.md", content: "Updated")
    assert_requested(:put, "http://localhost:3000/api/posts/test.md")
  end

  # --- delete_post ---

  def test_delete_post
    stub_request(:delete, "http://localhost:3000/api/posts/test.md")
      .to_return(status: 200, body: { message: "Post deleted" }.to_json, headers: json_headers)

    result = @client.delete_post("test.md")
    assert_equal "Post deleted", result["message"]
  end

  # --- publish_post ---

  def test_publish_post
    stub_request(:post, "http://localhost:3000/api/posts/test.md/publish")
      .to_return(status: 200, body: { post: { status: "sent" } }.to_json, headers: json_headers)

    result = @client.publish_post("test.md")
    assert_equal "sent", result["post"]["status"]
  end

  # --- history ---

  def test_history_with_pagination
    stub_request(:get, "http://localhost:3000/api/history")
      .with(query: { page: "2", per_page: "10" })
      .to_return(status: 200, body: { history: [], page: 2, per_page: 10, total: 25 }.to_json, headers: json_headers)

    result = @client.history(page: 2, per_page: 10)
    assert_equal 2, result["page"]
  end

  # --- platforms ---

  def test_platforms
    stub_request(:get, "http://localhost:3000/api/platforms")
      .to_return(status: 200, body: { platforms: [ { name: "bluesky", configured: true } ] }.to_json, headers: json_headers)

    result = @client.platforms
    assert_equal "bluesky", result["platforms"].first["name"]
  end

  # --- error handling ---

  def test_raises_authentication_error_on_401
    stub_request(:get, "http://localhost:3000/api/posts")
      .to_return(status: 401, body: { error: "Unauthorized" }.to_json, headers: json_headers)

    assert_raises(Blurt::Client::AuthenticationError) { @client.list_posts }
  end

  def test_raises_not_found_error_on_404
    stub_request(:get, "http://localhost:3000/api/posts/missing.md")
      .to_return(status: 404, body: { error: "Not found" }.to_json, headers: json_headers)

    assert_raises(Blurt::Client::NotFoundError) { @client.get_post("missing.md") }
  end

  def test_raises_server_error_on_503
    stub_request(:get, "http://localhost:3000/api/posts")
      .to_return(status: 503, body: { error: "BLURT_API_KEY not set" }.to_json, headers: json_headers)

    assert_raises(Blurt::Client::ServerError) { @client.list_posts }
  end

  def test_raises_connection_error_on_network_failure
    stub_request(:get, "http://localhost:3000/api/health")
      .to_raise(Faraday::ConnectionFailed.new("Connection refused"))

    error = assert_raises(Blurt::Client::ConnectionError) { @client.health }
    assert_includes error.message, "Cannot connect to"
  end

  def test_raises_connection_error_on_timeout
    stub_request(:get, "http://localhost:3000/api/health")
      .to_raise(Faraday::TimeoutError)

    assert_raises(Blurt::Client::ConnectionError) { @client.health }
  end

  def test_raises_generic_error_on_500
    stub_request(:get, "http://localhost:3000/api/posts")
      .to_return(status: 500, body: { error: "Internal error" }.to_json, headers: json_headers)

    error = assert_raises(Blurt::Client::Error) { @client.list_posts }
    assert_includes error.message, "500"
  end

  private

  def json_headers
    { "Content-Type" => "application/json" }
  end
end
