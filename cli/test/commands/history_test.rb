# frozen_string_literal: true

require "test_helper"

class HistoryCommandTest < Minitest::Test
  def setup
    @config = Blurt::Config.new(api_url: "http://localhost:3000", api_key: "test-key")
  end

  def test_displays_published_posts
    stub_history([sample_entry, sample_entry(filename: "second.md")])

    output = capture_io {
      Blurt::Commands::History.new(@config).run
    }.first

    assert_includes output, "2 published post(s)"
    assert_includes output, "my-post.md"
    assert_includes output, "second.md"
    assert_includes output, "bluesky, mastodon"
    assert_includes output, "Page 1 of 1 (2 total)"
  end

  def test_displays_empty_message
    stub_history([])

    output = capture_io {
      Blurt::Commands::History.new(@config).run
    }.first

    assert_includes output, "No published posts found."
  end

  def test_passes_page_filter
    stub_request(:get, "http://localhost:3000/api/history")
      .with(query: { page: "2" })
      .to_return(status: 200, body: {
        history: [], page: 2, per_page: 25, total: 50
      }.to_json, headers: json_headers)

    capture_io { Blurt::Commands::History.new(@config).run(page: 2) }

    assert_requested(:get, "http://localhost:3000/api/history", query: { page: "2" })
  end

  def test_passes_platform_filter
    stub_request(:get, "http://localhost:3000/api/history")
      .with(query: { platform: "bluesky" })
      .to_return(status: 200, body: {
        history: [], page: 1, per_page: 25, total: 0
      }.to_json, headers: json_headers)

    capture_io { Blurt::Commands::History.new(@config).run(platform: "bluesky") }

    assert_requested(:get, "http://localhost:3000/api/history", query: { platform: "bluesky" })
  end

  def test_displays_pagination_info
    stub_history([sample_entry], page: 2, per_page: 25, total: 50)

    output = capture_io {
      Blurt::Commands::History.new(@config).run
    }.first

    assert_includes output, "Page 2 of 2 (50 total)"
  end

  def test_truncates_multiple_urls
    entry = sample_entry(results: {
      "bluesky" => { "url" => "https://bsky.app/profile/test/post/123" },
      "mastodon" => { "url" => "https://mastodon.social/@test/456" },
      "linkedin" => { "url" => "https://linkedin.com/feed/update/789" }
    })
    stub_history([entry])

    output = capture_io {
      Blurt::Commands::History.new(@config).run
    }.first

    assert_includes output, "https://bsky.app/profile/test/post/123"
    assert_includes output, "(+2 more)"
  end

  def test_exits_with_error_when_no_api_key
    no_key_config = Blurt::Config.new(api_url: "http://localhost:3000")

    err_output = capture_io do
      assert_raises(SystemExit) {
        Blurt::Commands::History.new(no_key_config).run
      }
    end.last

    assert_includes err_output, "No API key configured"
  end

  def test_exits_with_error_on_auth_failure
    stub_request(:get, "http://localhost:3000/api/history")
      .to_return(status: 401, body: { error: "Unauthorized" }.to_json, headers: json_headers)

    err_output = capture_io do
      assert_raises(SystemExit) {
        Blurt::Commands::History.new(@config).run
      }
    end.last

    assert_includes err_output, "Invalid API key"
  end

  def test_exits_with_error_on_connection_failure
    stub_request(:get, "http://localhost:3000/api/history")
      .to_raise(Faraday::ConnectionFailed.new("Connection refused"))

    err_output = capture_io do
      assert_raises(SystemExit) {
        Blurt::Commands::History.new(@config).run
      }
    end.last

    assert_includes err_output, "Cannot connect to"
  end

  private

  def stub_history(entries, page: 1, per_page: 25, total: nil)
    total ||= entries.length
    stub_request(:get, "http://localhost:3000/api/history")
      .to_return(status: 200, body: {
        history: entries, page: page, per_page: per_page, total: total
      }.to_json, headers: json_headers)
  end

  def sample_entry(filename: "my-post.md", platforms: %w[bluesky mastodon], results: nil)
    results ||= {
      "bluesky" => { "url" => "https://bsky.app/profile/test/post/123", "publishedAt" => "2026-04-01T10:00:00Z" },
      "mastodon" => { "url" => "https://mastodon.social/@test/456", "publishedAt" => "2026-04-01T10:00:00Z" }
    }
    {
      "filename" => filename,
      "platforms" => platforms,
      "status" => "sent",
      "published_at" => "2026-04-01T10:00:00Z",
      "results" => results
    }
  end

  def json_headers
    { "Content-Type" => "application/json" }
  end
end
