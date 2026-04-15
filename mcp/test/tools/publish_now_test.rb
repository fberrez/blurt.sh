# frozen_string_literal: true

require "test_helper"
require "json"

class PublishNowToolTest < Minitest::Test
  def setup
    @server = build_server
  end

  def test_success_all_platforms
    stub_request(:post, "http://localhost:3000/api/posts/hello.md/publish")
      .to_return(status: 200, body: {
        results: [
          { platform: "bluesky", url: "https://bsky.app/x/1" },
          { platform: "mastodon", url: "https://mastodon.social/y/2" }
        ]
      }.to_json, headers: json_headers)

    result = call_tool(@server, "publish-now", { id: "hello.md" })
    text = result["content"].first["text"]
    assert_equal false, result["isError"]
    assert_includes text, "Published hello.md"
    assert_includes text, "bluesky: https://bsky.app/x/1"
    assert_includes text, "mastodon: https://mastodon.social/y/2"
  end

  def test_mixed_results
    stub_request(:post, "http://localhost:3000/api/posts/hello.md/publish")
      .to_return(status: 200, body: {
        results: [
          { platform: "bluesky", url: "https://bsky.app/x/1" },
          { platform: "mastodon", error: "rate limited" }
        ]
      }.to_json, headers: json_headers)

    result = call_tool(@server, "publish-now", { id: "hello.md" })
    text = result["content"].first["text"]
    assert_includes text, "bluesky: https://bsky.app/x/1"
    assert_includes text, "mastodon: FAILED — rate limited"
  end

  def test_not_found
    stub_request(:post, "http://localhost:3000/api/posts/missing.md/publish")
      .to_return(status: 404, body: { error: "Not found" }.to_json, headers: json_headers)

    result = call_tool(@server, "publish-now", { id: "missing.md" })
    assert_equal true, result["isError"]
    assert_includes result["content"].first["text"], "Not found: missing.md"
    assert_includes result["content"].first["text"], "list-queue"
  end

  def test_generic_error
    stub_request(:post, "http://localhost:3000/api/posts/hello.md/publish")
      .to_return(status: 500, body: { error: "boom" }.to_json, headers: json_headers)

    result = call_tool(@server, "publish-now", { id: "hello.md" })
    assert_equal true, result["isError"]
    assert_includes result["content"].first["text"], "Error:"
  end
end
