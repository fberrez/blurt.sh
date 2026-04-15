# frozen_string_literal: true

require "test_helper"
require "json"

class ListHistoryToolTest < Minitest::Test
  def setup
    @server = build_server
  end

  def test_with_posts
    stub_request(:get, "http://localhost:3000/api/history")
      .to_return(status: 200, body: {
        posts: [
          {
            filename: "hello.md",
            platforms: %w[bluesky mastodon],
            published_at: "2026-04-10T09:00:00Z",
            urls: ["https://bsky.app/x/1", "https://mastodon.social/y/2"]
          }
        ],
        pagination: { page: 1, total_pages: 3, total: 27 }
      }.to_json, headers: json_headers)

    result = call_tool(@server, "list-history", {})
    text = result["content"].first["text"]
    assert_includes text, "1 published post(s):"
    assert_includes text, "hello.md"
    assert_includes text, "bluesky, mastodon"
    assert_includes text, "+1 more"
    assert_includes text, "Page 1 of 3 (27 total)"
  end

  def test_empty
    stub_request(:get, "http://localhost:3000/api/history")
      .to_return(status: 200, body: { posts: [] }.to_json, headers: json_headers)

    result = call_tool(@server, "list-history", {})
    assert_includes result["content"].first["text"], "No published posts found."
  end

  def test_with_filters
    stub_request(:get, "http://localhost:3000/api/history")
      .with(query: { page: "2", platform: "bluesky" })
      .to_return(status: 200, body: { posts: [] }.to_json, headers: json_headers)

    result = call_tool(@server, "list-history", { page: 2, platform: "bluesky" })
    assert_includes result["content"].first["text"], "No published posts found."
  end

  def test_auth_error
    stub_request(:get, "http://localhost:3000/api/history")
      .to_return(status: 401, body: { error: "Unauthorized" }.to_json, headers: json_headers)

    result = call_tool(@server, "list-history", {})
    assert_equal true, result["isError"]
    assert_includes result["content"].first["text"], "Error:"
  end
end
