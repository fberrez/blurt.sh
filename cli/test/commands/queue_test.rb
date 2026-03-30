# frozen_string_literal: true

require "test_helper"

class QueueCommandTest < Minitest::Test
  def setup
    @config = Blurt::Config.new(api_url: "http://localhost:3000", api_key: "test-key")
  end

  def test_displays_queued_posts
    stub_posts([
      { id: "hello.md", filename: "hello.md", platforms: %w[bluesky mastodon], status: "queue", scheduled_at: nil },
      { id: "later.md", filename: "later.md", platforms: %w[devto], status: "queue", scheduled_at: "2026-04-01T09:00:00Z" }
    ])

    output = capture_io { Blurt::Commands::Queue.new(@config).run }.first

    assert_includes output, "2 post(s)"
    assert_includes output, "hello.md"
    assert_includes output, "bluesky, mastodon"
    assert_includes output, "later.md"
    assert_includes output, "2026-04-01T09:00:00Z"
  end

  def test_displays_empty_message
    stub_posts([])

    output = capture_io { Blurt::Commands::Queue.new(@config).run }.first

    assert_includes output, "No queue posts found."
  end

  def test_passes_status_filter
    stub_request(:get, "http://localhost:3000/api/posts")
      .with(query: { status: "sent" })
      .to_return(status: 200, body: { posts: [] }.to_json, headers: json_headers)

    capture_io { Blurt::Commands::Queue.new(@config).run(status: "sent") }

    assert_requested(:get, "http://localhost:3000/api/posts", query: { status: "sent" })
  end

  def test_passes_platform_filter
    stub_request(:get, "http://localhost:3000/api/posts")
      .with(query: { status: "queue", platform: "bluesky" })
      .to_return(status: 200, body: { posts: [] }.to_json, headers: json_headers)

    capture_io { Blurt::Commands::Queue.new(@config).run(status: "queue", platform: "bluesky") }

    assert_requested(:get, "http://localhost:3000/api/posts", query: { status: "queue", platform: "bluesky" })
  end

  def test_exits_with_error_when_no_api_key
    no_key_config = Blurt::Config.new(api_url: "http://localhost:3000")

    err_output = capture_io do
      assert_raises(SystemExit) { Blurt::Commands::Queue.new(no_key_config).run }
    end.last

    assert_includes err_output, "No API key configured"
  end

  def test_exits_with_error_on_auth_failure
    stub_request(:get, "http://localhost:3000/api/posts")
      .with(query: hash_including(status: "queue"))
      .to_return(status: 401, body: { error: "Unauthorized" }.to_json, headers: json_headers)

    err_output = capture_io do
      assert_raises(SystemExit) { Blurt::Commands::Queue.new(@config).run }
    end.last

    assert_includes err_output, "Invalid API key"
  end

  def test_exits_with_error_on_connection_failure
    stub_request(:get, "http://localhost:3000/api/posts")
      .with(query: hash_including(status: "queue"))
      .to_raise(Faraday::ConnectionFailed.new("Connection refused"))

    err_output = capture_io do
      assert_raises(SystemExit) { Blurt::Commands::Queue.new(@config).run }
    end.last

    assert_includes err_output, "Cannot connect to"
  end

  private

  def stub_posts(posts)
    stub_request(:get, "http://localhost:3000/api/posts")
      .with(query: hash_including(status: "queue"))
      .to_return(status: 200, body: { posts: posts }.to_json, headers: json_headers)
  end

  def json_headers
    { "Content-Type" => "application/json" }
  end
end
