# frozen_string_literal: true

require "test_helper"

class QueueScannerTest < ActiveSupport::TestCase
  setup do
    @queue_dir = Rails.root.join("tmp", "test_queue_#{SecureRandom.hex(4)}")
    FileUtils.mkdir_p(@queue_dir)
    @original_queue_dir = QueueScanner::QUEUE_DIR
    QueueScanner.send(:remove_const, :QUEUE_DIR)
    QueueScanner.const_set(:QUEUE_DIR, @queue_dir.to_s)

    # Clear logged scheduled posts between tests
    QueueScanner.instance_variable_get(:@logged_scheduled_mutex).synchronize do
      QueueScanner.instance_variable_get(:@logged_scheduled_posts).clear
    end

    @original_env = ENV.to_h
    ENV["BLUESKY_IDENTIFIER"] = "user.bsky.social"
    ENV["BLUESKY_PASSWORD"] = "pass"
  end

  teardown do
    FileUtils.rm_rf(@queue_dir)
    QueueScanner.send(:remove_const, :QUEUE_DIR)
    QueueScanner.const_set(:QUEUE_DIR, @original_queue_dir)
    ENV.replace(@original_env)
  end

  test "returns empty array when queue directory is empty" do
    assert_equal [], QueueScanner.pending_posts
  end

  test "skips .gitkeep files" do
    File.write(File.join(@queue_dir, ".gitkeep"), "")
    assert_equal [], QueueScanner.pending_posts
  end

  test "parses flat markdown file" do
    write_post("hello.md", platforms: %w[bluesky], content: "Hello world")

    posts = QueueScanner.pending_posts
    assert_equal 1, posts.length
    assert_equal "hello.md", posts.first.filename
    assert_equal "Hello world", posts.first.content
  end

  test "parses directory post with post.md" do
    dir = File.join(@queue_dir, "my-post")
    FileUtils.mkdir_p(dir)
    write_post("my-post/post.md", platforms: %w[bluesky], content: "Dir post")

    posts = QueueScanner.pending_posts
    assert_equal 1, posts.length
    assert_equal "post.md", posts.first.filename
  end

  test "skips posts with future scheduledAt" do
    future = (Time.current + 1.hour).utc.iso8601
    write_post("future.md", platforms: %w[bluesky], content: "Later", scheduled_at: future)

    assert_equal [], QueueScanner.pending_posts
  end

  test "includes posts with past scheduledAt" do
    past = (Time.current - 1.hour).utc.iso8601
    write_post("past.md", platforms: %w[bluesky], content: "Already due", scheduled_at: past)

    posts = QueueScanner.pending_posts
    assert_equal 1, posts.length
  end

  test "skips posts with no configured platforms" do
    ENV.delete("BLUESKY_IDENTIFIER")
    ENV.delete("MASTODON_URL")
    ENV.delete("LINKEDIN_ACCESS_TOKEN")
    ENV.delete("MEDIUM_INTEGRATION_TOKEN")
    ENV.delete("DEVTO_API_KEY")
    ENV.delete("SUBSTACK_SMTP_HOST")
    ENV.delete("SUBSTACK_SMTP_USER")

    write_post("orphan.md", platforms: %w[bluesky], content: "No platform configured")

    assert_equal [], QueueScanner.pending_posts
  end

  test "skips .publishing files" do
    File.write(File.join(@queue_dir, "locked.md.publishing"), "---\nplatforms:\n  - bluesky\n---\n\nLocked")

    assert_equal [], QueueScanner.pending_posts
  end

  test "skips files with invalid frontmatter" do
    # Psych::SyntaxError is raised for truly malformed YAML
    File.write(File.join(@queue_dir, "bad.md"), "---\n!!invalid: [broken\n---\n\nContent")

    assert_equal [], QueueScanner.pending_posts
  end

  test "skips non-markdown files" do
    File.write(File.join(@queue_dir, "readme.txt"), "not a post")

    assert_equal [], QueueScanner.pending_posts
  end

  test "lock! renames file with .publishing suffix" do
    write_post("lockme.md", platforms: %w[bluesky], content: "Lock test")
    post = QueueScanner.pending_posts.first

    locked_path = QueueScanner.lock!(post)

    assert locked_path.end_with?(".publishing")
    assert File.exist?(locked_path)
    refute File.exist?(File.join(@queue_dir, "lockme.md"))
  end

  test "unlock! renames .publishing back to original" do
    write_post("unlockme.md", platforms: %w[bluesky], content: "Unlock test")
    post = QueueScanner.pending_posts.first
    locked_path = QueueScanner.lock!(post)

    QueueScanner.unlock!(locked_path, post.file_path)

    assert File.exist?(File.join(@queue_dir, "unlockme.md"))
    refute File.exist?(locked_path)
  end

  private

  def write_post(relative_path, platforms:, content:, scheduled_at: nil)
    full_path = File.join(@queue_dir, relative_path)
    FileUtils.mkdir_p(File.dirname(full_path))

    frontmatter = { "platforms" => platforms }
    frontmatter["scheduledAt"] = scheduled_at if scheduled_at

    File.write(full_path, "#{frontmatter.to_yaml}---\n\n#{content}\n")
  end
end
