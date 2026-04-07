# frozen_string_literal: true

require "test_helper"

class PublishCommandTest < Minitest::Test
  def setup
    @config = Blurt::Config.new(api_url: "http://localhost:3000", api_key: "test-key")
  end

  def test_publishes_post_successfully
    stub_publish_success

    output = capture_io {
      Blurt::Commands::Publish.new(@config).run(id: "my-post.md")
    }.first

    assert_includes output, "Published: my-post.md"
    assert_includes output, "Status: sent"
    assert_includes output, "bluesky: https://bsky.app/profile/test/post/123"
    assert_includes output, "mastodon: https://mastodon.social/@test/456"
  end

  def test_displays_mixed_results
    stub_publish_mixed

    output = capture_io {
      Blurt::Commands::Publish.new(@config).run(id: "my-post.md")
    }.first

    assert_includes output, "bluesky: https://bsky.app/profile/test/post/123"
    assert_includes output, "linkedin: FAILED"
    assert_includes output, "Token expired"
  end

  def test_exits_when_post_not_found
    stub_request(:post, "http://localhost:3000/api/posts/missing.md/publish")
      .to_return(status: 404, body: { error: "Not found" }.to_json, headers: json_headers)

    err_output = capture_io do
      assert_raises(SystemExit) {
        Blurt::Commands::Publish.new(@config).run(id: "missing.md")
      }
    end.last

    assert_includes err_output, "Post not found: missing.md"
  end

  def test_exits_with_error_when_no_api_key
    no_key_config = Blurt::Config.new(api_url: "http://localhost:3000")

    err_output = capture_io do
      assert_raises(SystemExit) {
        Blurt::Commands::Publish.new(no_key_config).run(id: "my-post.md")
      }
    end.last

    assert_includes err_output, "No API key configured"
  end

  def test_exits_with_error_on_auth_failure
    stub_request(:post, "http://localhost:3000/api/posts/my-post.md/publish")
      .to_return(status: 401, body: { error: "Unauthorized" }.to_json, headers: json_headers)

    err_output = capture_io do
      assert_raises(SystemExit) {
        Blurt::Commands::Publish.new(@config).run(id: "my-post.md")
      }
    end.last

    assert_includes err_output, "Invalid API key"
  end

  def test_exits_with_error_on_connection_failure
    stub_request(:post, "http://localhost:3000/api/posts/my-post.md/publish")
      .to_raise(Faraday::ConnectionFailed.new("Connection refused"))

    err_output = capture_io do
      assert_raises(SystemExit) {
        Blurt::Commands::Publish.new(@config).run(id: "my-post.md")
      }
    end.last

    assert_includes err_output, "Cannot connect to"
  end

  private

  def stub_publish_success
    stub_request(:post, "http://localhost:3000/api/posts/my-post.md/publish")
      .to_return(status: 200, body: {
        post: {
          filename: "my-post.md",
          status: "sent",
          results: {
            bluesky: { url: "https://bsky.app/profile/test/post/123", published_at: "2026-04-01T10:00:00Z" },
            mastodon: { url: "https://mastodon.social/@test/456", published_at: "2026-04-01T10:00:00Z" }
          }
        }
      }.to_json, headers: json_headers)
  end

  def stub_publish_mixed
    stub_request(:post, "http://localhost:3000/api/posts/my-post.md/publish")
      .to_return(status: 200, body: {
        post: {
          filename: "my-post.md",
          status: "sent",
          results: {
            bluesky: { url: "https://bsky.app/profile/test/post/123", published_at: "2026-04-01T10:00:00Z" },
            linkedin: { error: "Token expired" }
          }
        }
      }.to_json, headers: json_headers)
  end

  def json_headers
    { "Content-Type" => "application/json" }
  end
end
