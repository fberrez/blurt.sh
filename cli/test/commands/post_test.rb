# frozen_string_literal: true

require "test_helper"
require "tempfile"

class PostCommandTest < Minitest::Test
  def setup
    @config = Blurt::Config.new(api_url: "http://localhost:3000", api_key: "test-key")
  end

  def test_creates_post_with_inline_content
    stub_create_post

    output = capture_io {
      Blurt::Commands::Post.new(@config).run(
        content: "Hello world!",
        platforms: %w[bluesky mastodon]
      )
    }.first

    assert_includes output, "Post created: my-post.md"
    assert_includes output, "bluesky, mastodon"
    assert_includes output, "queue"

    assert_requested(:post, "http://localhost:3000/api/posts") do |req|
      body = JSON.parse(req.body)
      body["content"] == "Hello world!" && body["platforms"] == %w[bluesky mastodon]
    end
  end

  def test_creates_post_from_file_with_frontmatter
    stub_create_post

    file = Tempfile.new(["test-post", ".md"])
    file.write("---\nplatforms:\n  - bluesky\n  - mastodon\ntitle: My Article\n---\nHello from file!")
    file.rewind

    output = capture_io {
      Blurt::Commands::Post.new(@config).run(file: file.path)
    }.first

    assert_includes output, "Post created: my-post.md"

    assert_requested(:post, "http://localhost:3000/api/posts") do |req|
      body = JSON.parse(req.body)
      body["content"] == "Hello from file!" &&
        body["platforms"] == %w[bluesky mastodon] &&
        body["title"] == "My Article"
    end
  ensure
    file&.close
    file&.unlink
  end

  def test_creates_post_from_file_without_frontmatter
    stub_create_post

    file = Tempfile.new(["test-post", ".md"])
    file.write("Just plain content")
    file.rewind

    output = capture_io {
      Blurt::Commands::Post.new(@config).run(
        file: file.path,
        platforms: %w[bluesky]
      )
    }.first

    assert_includes output, "Post created: my-post.md"

    assert_requested(:post, "http://localhost:3000/api/posts") do |req|
      body = JSON.parse(req.body)
      body["content"] == "Just plain content" && body["platforms"] == %w[bluesky]
    end
  ensure
    file&.close
    file&.unlink
  end

  def test_cli_flags_override_frontmatter
    stub_create_post

    file = Tempfile.new(["test-post", ".md"])
    file.write("---\nplatforms:\n  - bluesky\ntitle: Original\n---\nContent here")
    file.rewind

    capture_io {
      Blurt::Commands::Post.new(@config).run(
        file: file.path,
        platforms: %w[mastodon],
        title: "Overridden"
      )
    }

    assert_requested(:post, "http://localhost:3000/api/posts") do |req|
      body = JSON.parse(req.body)
      body["platforms"] == %w[mastodon] && body["title"] == "Overridden"
    end
  ensure
    file&.close
    file&.unlink
  end

  def test_frontmatter_extracts_scheduled_at
    stub_create_post(scheduled_at: "2026-04-01T09:00:00Z")

    file = Tempfile.new(["test-post", ".md"])
    file.write("---\nplatforms:\n  - bluesky\nscheduled_at: '2026-04-01T09:00:00Z'\n---\nScheduled post")
    file.rewind

    output = capture_io {
      Blurt::Commands::Post.new(@config).run(file: file.path)
    }.first

    assert_includes output, "Scheduled: 2026-04-01T09:00:00Z"

    assert_requested(:post, "http://localhost:3000/api/posts") do |req|
      body = JSON.parse(req.body)
      body["scheduled_at"] == "2026-04-01T09:00:00Z"
    end
  ensure
    file&.close
    file&.unlink
  end

  def test_exits_when_no_content_or_file
    err_output = capture_io do
      assert_raises(SystemExit) {
        Blurt::Commands::Post.new(@config).run
      }
    end.last

    assert_includes err_output, "Provide content as an argument or use --file"
  end

  def test_exits_when_file_not_found
    err_output = capture_io do
      assert_raises(SystemExit) {
        Blurt::Commands::Post.new(@config).run(file: "/nonexistent/post.md")
      }
    end.last

    assert_includes err_output, "File not found: /nonexistent/post.md"
  end

  def test_exits_when_no_platforms
    err_output = capture_io do
      assert_raises(SystemExit) {
        Blurt::Commands::Post.new(@config).run(content: "Hello")
      }
    end.last

    assert_includes err_output, "No platforms specified"
  end

  def test_exits_when_content_empty
    err_output = capture_io do
      assert_raises(SystemExit) {
        Blurt::Commands::Post.new(@config).run(content: "   ", platforms: %w[bluesky])
      }
    end.last

    assert_includes err_output, "Post content cannot be empty"
  end

  def test_exits_with_error_when_no_api_key
    no_key_config = Blurt::Config.new(api_url: "http://localhost:3000")

    err_output = capture_io do
      assert_raises(SystemExit) {
        Blurt::Commands::Post.new(no_key_config).run(content: "Hello", platforms: %w[bluesky])
      }
    end.last

    assert_includes err_output, "No API key configured"
  end

  def test_exits_with_error_on_auth_failure
    stub_request(:post, "http://localhost:3000/api/posts")
      .to_return(status: 401, body: { error: "Unauthorized" }.to_json, headers: json_headers)

    err_output = capture_io do
      assert_raises(SystemExit) {
        Blurt::Commands::Post.new(@config).run(content: "Hello", platforms: %w[bluesky])
      }
    end.last

    assert_includes err_output, "Invalid API key"
  end

  def test_exits_with_error_on_connection_failure
    stub_request(:post, "http://localhost:3000/api/posts")
      .to_raise(Faraday::ConnectionFailed.new("Connection refused"))

    err_output = capture_io do
      assert_raises(SystemExit) {
        Blurt::Commands::Post.new(@config).run(content: "Hello", platforms: %w[bluesky])
      }
    end.last

    assert_includes err_output, "Cannot connect to"
  end

  private

  def stub_create_post(scheduled_at: nil)
    post_data = {
      id: "my-post.md", filename: "my-post.md",
      platforms: %w[bluesky mastodon], status: "queue"
    }
    post_data[:scheduled_at] = scheduled_at if scheduled_at

    stub_request(:post, "http://localhost:3000/api/posts")
      .to_return(status: 201, body: { post: post_data }.to_json, headers: json_headers)
  end

  def json_headers
    { "Content-Type" => "application/json" }
  end
end
