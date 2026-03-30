# frozen_string_literal: true

require "test_helper"

class StatusCommandTest < Minitest::Test
  def setup
    @config = Blurt::Config.new(api_url: "http://localhost:3000", api_key: "test-key")
  end

  def test_displays_server_status
    stub_health

    output = capture_io { Blurt::Commands::Status.new(@config).run }.first

    assert_includes output, "Blurt Status"
    assert_includes output, "http://localhost:3000 (ok)"
    assert_includes output, "3 pending"
    assert_includes output, "42 total"
    assert_includes output, "1 total"
    assert_includes output, "bluesky, mastodon"
    assert_includes output, "2/6 configured"
    assert_includes output, "connected"
    assert_includes output, "polling every 60s"
  end

  def test_shows_degraded_status
    stub_request(:get, "http://localhost:3000/api/health")
      .to_return(status: 200, body: health_response(status: "degraded", worker: false).to_json,
        headers: json_headers)

    output = capture_io { Blurt::Commands::Status.new(@config).run }.first

    assert_includes output, "(degraded)"
    assert_includes output, "disconnected"
  end

  def test_handles_connection_error
    stub_request(:get, "http://localhost:3000/api/health")
      .to_raise(Faraday::ConnectionFailed.new("Connection refused"))

    err_output = capture_io do
      assert_raises(SystemExit) { Blurt::Commands::Status.new(@config).run }
    end.last

    assert_includes err_output, "Cannot connect to"
    assert_includes err_output, "Is the Blurt server running"
  end

  private

  def stub_health
    stub_request(:get, "http://localhost:3000/api/health")
      .to_return(status: 200, body: health_response.to_json, headers: json_headers)
  end

  def health_response(status: "ok", worker: true)
    {
      status: status,
      queue: { pending: 3 },
      sent: { total: 42 },
      failed: { total: 1 },
      platforms: { configured: %w[bluesky mastodon], count: 2 },
      solid_queue: { connected: worker },
      poll_interval_ms: 60_000
    }
  end

  def json_headers
    { "Content-Type" => "application/json" }
  end
end
