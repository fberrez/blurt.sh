# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class Api::HistoryControllerTest < ActionDispatch::IntegrationTest
  setup do
    @tmp_dir = Dir.mktmpdir("blurt_history_test")
    @sent_dir = File.join(@tmp_dir, "sent")
    FileUtils.mkdir_p(@sent_dir)

    @original_mover_sent = PostMover::SENT_DIR
    silence_warnings do
      PostMover.const_set(:SENT_DIR, @sent_dir)
    end

    @api_key = "test-api-key-#{SecureRandom.hex(8)}"
    ENV["BLURT_API_KEY"] = @api_key
  end

  teardown do
    silence_warnings do
      PostMover.const_set(:SENT_DIR, @original_mover_sent)
    end
    ENV.delete("BLURT_API_KEY")
    FileUtils.rm_rf(@tmp_dir)
  end

  test "index returns publish log entries" do
    PublishLog.create!(
      filename: "test-post.md",
      title: "Test Post",
      status: "sent",
      platforms: %w[bluesky],
      results: { "bluesky" => { "url" => "https://bsky.app/test" } },
      published_at: Time.current
    )

    get api_history_index_url, headers: auth_headers
    assert_response :success

    body = JSON.parse(response.body)
    assert_equal 1, body["history"].length
    assert_equal "test-post.md", body["history"].first["filename"]
    assert_equal 1, body["page"]
    assert_equal 25, body["per_page"]
    assert_equal 1, body["total"]
  end

  test "index paginates results" do
    30.times do |i|
      PublishLog.create!(
        filename: "post-#{i}.md",
        status: "sent",
        platforms: %w[bluesky],
        results: {},
        published_at: i.hours.ago
      )
    end

    get api_history_index_url, params: { per_page: 10 }, headers: auth_headers
    body = JSON.parse(response.body)
    assert_equal 10, body["history"].length
    assert_equal 30, body["total"]

    get api_history_index_url, params: { page: 2, per_page: 10 }, headers: auth_headers
    body = JSON.parse(response.body)
    assert_equal 10, body["history"].length
    assert_equal 2, body["page"]
  end

  test "index filters by platform" do
    PublishLog.create!(filename: "bsky.md", status: "sent", platforms: %w[bluesky], results: {}, published_at: Time.current)
    PublishLog.create!(filename: "devto.md", status: "sent", platforms: %w[devto], results: {}, published_at: Time.current)

    get api_history_index_url, params: { platform: "bluesky" }, headers: auth_headers
    body = JSON.parse(response.body)
    assert_equal 1, body["history"].length
    assert_equal "bsky.md", body["history"].first["filename"]
  end

  test "show returns single entry" do
    PublishLog.create!(
      filename: "detail.md",
      title: "Detail Post",
      status: "sent",
      platforms: %w[bluesky mastodon],
      results: { "bluesky" => { "url" => "https://bsky.app/test" } },
      published_at: Time.current
    )

    get api_history_url("detail.md"), headers: auth_headers
    assert_response :success

    body = JSON.parse(response.body)
    assert_equal "detail.md", body["post"]["filename"]
    assert_equal "Detail Post", body["post"]["title"]
  end

  test "show falls back to filesystem when no log entry" do
    File.write(File.join(@sent_dir, "fallback.md"), <<~MD)
      ---
      title: "Fallback Post"
      platforms:
        - bluesky
      ---

      Fallback content.
    MD

    get api_history_url("fallback.md"), headers: auth_headers
    assert_response :success

    body = JSON.parse(response.body)
    assert_equal "fallback.md", body["post"]["filename"]
    assert_equal "sent", body["post"]["status"]
  end

  test "show returns 404 when not found anywhere" do
    get api_history_url("nope.md"), headers: auth_headers
    assert_response :not_found
  end

  private

  def auth_headers
    { "Authorization" => "Bearer #{@api_key}" }
  end
end
