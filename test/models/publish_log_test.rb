# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class PublishLogTest < ActiveSupport::TestCase
  setup do
    @tmp_dir = Dir.mktmpdir("blurt_log_test")
    @post_path = File.join(@tmp_dir, "test-post.md")
    File.write(@post_path, <<~MD)
      ---
      title: "Log Test Post"
      platforms:
        - bluesky
        - devto
      ---

      Test content.
    MD
    @post = Post.from_file(@post_path)
  end

  teardown do
    FileUtils.rm_rf(@tmp_dir)
  end

  test "record! creates entry with correct attributes for sent" do
    results = {
      "bluesky" => { url: "https://bsky.app/profile/test/post/123", published_at: Time.current },
      "devto" => { url: "https://dev.to/user/test-123", published_at: Time.current }
    }

    log = PublishLog.record!(post: @post, results: results, status: :sent, destination_path: "/sent/test-post.md")

    assert_equal "test-post.md", log.filename
    assert_equal "Log Test Post", log.title
    assert_equal "sent", log.status
    assert_equal %w[bluesky devto], log.platforms
    assert_equal "https://bsky.app/profile/test/post/123", log.results["bluesky"]["url"]
    assert_equal "https://dev.to/user/test-123", log.results["devto"]["url"]
    assert_empty log.publish_errors
    assert_equal "/sent/test-post.md", log.destination_path
    assert_not_nil log.published_at
  end

  test "record! creates entry with errors for failed" do
    results = {
      "bluesky" => { url: "https://bsky.app/profile/test/post/123", published_at: Time.current },
      "devto" => { error: "Faraday::ServerError: 500" }
    }

    log = PublishLog.record!(post: @post, results: results, status: :failed, destination_path: "/failed/test-post.md")

    assert_equal "failed", log.status
    assert_equal "https://bsky.app/profile/test/post/123", log.results["bluesky"]["url"]
    assert_equal "Faraday::ServerError: 500", log.publish_errors["devto"]
  end

  test "sent scope returns only sent logs" do
    PublishLog.create!(filename: "a.md", status: "sent", platforms: [], results: {}, published_at: Time.current)
    PublishLog.create!(filename: "b.md", status: "failed", platforms: [], results: {}, published_at: Time.current)

    assert_equal 1, PublishLog.sent.count
    assert_equal "a.md", PublishLog.sent.first.filename
  end

  test "failed scope returns only failed logs" do
    PublishLog.create!(filename: "a.md", status: "sent", platforms: [], results: {}, published_at: Time.current)
    PublishLog.create!(filename: "b.md", status: "failed", platforms: [], results: {}, published_at: Time.current)

    assert_equal 1, PublishLog.failed.count
    assert_equal "b.md", PublishLog.failed.first.filename
  end

  test "for_platform scope filters by platform" do
    PublishLog.create!(filename: "a.md", status: "sent", platforms: %w[bluesky mastodon], results: {}, published_at: Time.current)
    PublishLog.create!(filename: "b.md", status: "sent", platforms: %w[devto], results: {}, published_at: Time.current)

    assert_equal 1, PublishLog.for_platform("bluesky").count
    assert_equal "a.md", PublishLog.for_platform("bluesky").first.filename
  end

  test "date range scopes filter correctly" do
    PublishLog.create!(filename: "old.md", status: "sent", platforms: [], results: {}, published_at: 3.days.ago)
    PublishLog.create!(filename: "new.md", status: "sent", platforms: [], results: {}, published_at: Time.current)

    assert_equal 1, PublishLog.after_date(1.day.ago).count
    assert_equal "new.md", PublishLog.after_date(1.day.ago).first.filename

    assert_equal 1, PublishLog.before_date(1.day.ago).count
    assert_equal "old.md", PublishLog.before_date(1.day.ago).first.filename
  end

  test "validates presence of filename and status" do
    log = PublishLog.new
    assert_not log.valid?
    assert_includes log.errors[:filename], "can't be blank"
    assert_includes log.errors[:status], "can't be blank"
  end

  test "validates status inclusion" do
    log = PublishLog.new(filename: "test.md", status: "invalid")
    assert_not log.valid?
    assert_includes log.errors[:status], "is not included in the list"
  end
end
