# frozen_string_literal: true

require "test_helper"
require "json"

class GetPostToolTest < Minitest::Test
  def setup
    @server = build_server
  end

  def test_success
    stub_request(:get, "http://localhost:3000/api/posts/hello.md")
      .to_return(status: 200, body: {
        post: {
          filename: "hello.md",
          status: "queue",
          platforms: %w[bluesky mastodon],
          scheduled_at: "2026-04-20T13:00:00Z",
          content: "Hello world"
        }
      }.to_json, headers: json_headers)

    result = call_tool(@server, "get-post", { id: "hello.md" })
    text = result["content"].first["text"]
    assert_equal false, result["isError"]
    assert_includes text, "Post: hello.md"
    assert_includes text, "Status: queue"
    assert_includes text, "bluesky, mastodon"
    assert_includes text, "Scheduled: 2026-04-20T13:00:00Z"
    assert_includes text, "Hello world"
  end

  def test_not_found
    stub_request(:get, "http://localhost:3000/api/posts/missing.md")
      .to_return(status: 404, body: { error: "Not found" }.to_json, headers: json_headers)

    result = call_tool(@server, "get-post", { id: "missing.md" })
    assert_equal true, result["isError"]
    assert_includes result["content"].first["text"], "Not found: missing.md"
  end
end
