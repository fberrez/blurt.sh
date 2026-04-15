# frozen_string_literal: true

require "test_helper"
require "json"

class QueueResourceTest < Minitest::Test
  def setup
    @server = build_server
  end

  def test_listed_in_resources_list
    result = list_resources(@server)
    uris = result["resources"].map { |r| r["uri"] }
    assert_includes uris, "blurt://queue"
  end

  def test_read_returns_json_payload
    stub_request(:get, "http://localhost:3000/api/posts")
      .with(query: { status: "queue" })
      .to_return(status: 200, body: {
        posts: [
          { filename: "hello.md", platforms: %w[bluesky], status: "queue", scheduled_at: nil },
          { filename: "world.md", platforms: %w[mastodon], status: "queue", scheduled_at: "2026-04-20T13:00:00Z" }
        ]
      }.to_json, headers: json_headers)

    result = read_resource(@server, "blurt://queue")
    contents = result["contents"]
    assert_equal 1, contents.length
    assert_equal "blurt://queue", contents.first["uri"]
    assert_equal "application/json", contents.first["mimeType"]

    payload = JSON.parse(contents.first["text"])
    assert_equal 2, payload["count"]
    assert_equal "hello.md", payload["posts"][0]["filename"]
  end

  def test_read_when_api_errors
    stub_request(:get, "http://localhost:3000/api/posts")
      .with(query: { status: "queue" })
      .to_return(status: 500, body: { error: "boom" }.to_json, headers: json_headers)

    result = read_resource(@server, "blurt://queue")
    payload = JSON.parse(result["contents"].first["text"])
    assert payload["error"]
  end
end
