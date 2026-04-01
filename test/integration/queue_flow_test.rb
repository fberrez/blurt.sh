# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class QueueFlowTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @tmp_dir = Dir.mktmpdir("blurt_test")
    @queue_dir = File.join(@tmp_dir, "queue")
    @sent_dir = File.join(@tmp_dir, "sent")
    @failed_dir = File.join(@tmp_dir, "failed")
    FileUtils.mkdir_p([@queue_dir, @sent_dir, @failed_dir])

    # Override directory constants to use temp dirs
    @original_scanner_dir = QueueScanner::QUEUE_DIR
    @original_mover_queue = PostMover::QUEUE_DIR
    @original_mover_sent = PostMover::SENT_DIR
    @original_mover_failed = PostMover::FAILED_DIR

    silence_warnings do
      QueueScanner.const_set(:QUEUE_DIR, @queue_dir)
      PostMover.const_set(:QUEUE_DIR, @queue_dir)
      PostMover.const_set(:SENT_DIR, @sent_dir)
      PostMover.const_set(:FAILED_DIR, @failed_dir)
    end

    # Configure all 6 platforms via ENV
    @env_vars = {
      "BLUESKY_IDENTIFIER" => "test.bsky.social",
      "BLUESKY_PASSWORD" => "test-password",
      "MASTODON_URL" => "https://mastodon.test",
      "MASTODON_ACCESS_TOKEN" => "masto-token",
      "LINKEDIN_ACCESS_TOKEN" => "li-token",
      "LINKEDIN_PERSON_ID" => "li-person-123",
      "MEDIUM_INTEGRATION_TOKEN" => "medium-token",
      "DEVTO_API_KEY" => "devto-key",
      "SUBSTACK_SMTP_HOST" => "smtp.test.com",
      "SUBSTACK_SMTP_PORT" => "587",
      "SUBSTACK_SMTP_USER" => "test@test.com",
      "SUBSTACK_SMTP_PASSWORD" => "smtp-password",
      "SUBSTACK_FROM_ADDRESS" => "from@test.com",
      "SUBSTACK_TO_ADDRESS" => "to@substack.com"
    }
    @env_vars.each { |k, v| ENV[k] = v }

    ActionMailer::Base.deliveries.clear
  end

  teardown do
    silence_warnings do
      QueueScanner.const_set(:QUEUE_DIR, @original_scanner_dir)
      PostMover.const_set(:QUEUE_DIR, @original_mover_queue)
      PostMover.const_set(:SENT_DIR, @original_mover_sent)
      PostMover.const_set(:FAILED_DIR, @original_mover_failed)
    end

    @env_vars.each_key { |k| ENV.delete(k) }
    FileUtils.rm_rf(@tmp_dir)
  end

  test "publishes to all 6 platforms and moves to sent with enriched frontmatter" do
    create_post_file("all-platforms.md", <<~MD)
      ---
      title: "Test Post for All Platforms"
      platforms:
        - bluesky
        - mastodon
        - linkedin
        - medium
        - devto
        - substack
      ---

      Hello world! Check out https://blurt.sh for more.
    MD

    stub_all_platforms

    perform_enqueued_jobs do
      ScanQueueJob.perform_now
    end

    # Post should be gone from queue
    assert_empty Dir.children(@queue_dir).reject { |f| f == ".gitkeep" }

    # Post should be in sent/
    sent_files = Dir.children(@sent_dir)
    assert_equal 1, sent_files.length

    # Parse enriched frontmatter
    sent_content = File.read(File.join(@sent_dir, sent_files.first))
    loader = FrontMatterParser::Loader::Yaml.new(allowlist_classes: [Time, Date])
    parsed = FrontMatterParser::Parser.new(:md, loader: loader).call(sent_content)
    fm = parsed.front_matter

    assert fm["publishedAt"].present?, "Should have publishedAt"
    assert fm["results"].is_a?(Hash), "Should have results hash"

    %w[bluesky mastodon linkedin medium devto substack].each do |platform|
      assert fm["results"][platform].present?, "Should have result for #{platform}"
      assert fm["results"][platform]["url"].present?, "Should have URL for #{platform}"
    end

    # Substack should have sent an email
    assert_equal 1, ActionMailer::Base.deliveries.size
  end

  test "scheduled post is skipped" do
    create_post_file("future-post.md", <<~MD)
      ---
      title: "Future Post"
      platforms:
        - devto
      scheduledAt: #{(Time.current + 1.day).iso8601}
      ---

      This should not be published yet.
    MD

    perform_enqueued_jobs do
      ScanQueueJob.perform_now
    end

    # Post should still be in queue
    queue_files = Dir.children(@queue_dir).reject { |f| f == ".gitkeep" }
    assert_equal 1, queue_files.length
    assert_equal "future-post.md", queue_files.first

    # Nothing in sent/ or failed/
    assert_empty Dir.children(@sent_dir)
    assert_empty Dir.children(@failed_dir)
  end

  test "failed publish moves to failed with errors in frontmatter" do
    create_post_file("failing-post.md", <<~MD)
      ---
      title: "Failing Post"
      platforms:
        - devto
      ---

      This will fail.
    MD

    stub_request(:post, "https://dev.to/api/articles")
      .to_return(status: 500, body: { error: "Internal Server Error" }.to_json)

    perform_enqueued_jobs do
      ScanQueueJob.perform_now
    end

    # Post should be gone from queue
    assert_empty Dir.children(@queue_dir).reject { |f| f == ".gitkeep" }

    # Post should be in failed/
    failed_files = Dir.children(@failed_dir)
    assert_equal 1, failed_files.length

    # Parse enriched frontmatter
    failed_content = File.read(File.join(@failed_dir, failed_files.first))
    loader = FrontMatterParser::Loader::Yaml.new(allowlist_classes: [Time, Date])
    parsed = FrontMatterParser::Parser.new(:md, loader: loader).call(failed_content)
    fm = parsed.front_matter

    assert fm["failedAt"].present?, "Should have failedAt"
    assert fm["errors"].is_a?(Hash), "Should have errors hash"
    assert fm["errors"]["devto"].present?, "Should have error for devto"
  end

  private

  def create_post_file(filename, content)
    File.write(File.join(@queue_dir, filename), content)
  end

  def stub_all_platforms
    # Bluesky: createSession + createRecord (no images, text is short enough to skip link preview fetch)
    stub_request(:post, "https://bsky.social/xrpc/com.atproto.server.createSession")
      .to_return(
        status: 200,
        body: { did: "did:plc:test123", accessJwt: "jwt-token", handle: "test.bsky.social" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    # Bluesky link preview: OG metadata fetch for https://blurt.sh
    stub_request(:get, "https://blurt.sh")
      .to_return(
        status: 200,
        body: '<html><head><title>Blurt</title><meta property="og:title" content="Blurt"></head><body></body></html>',
        headers: { "Content-Type" => "text/html" }
      )

    stub_request(:post, "https://bsky.social/xrpc/com.atproto.repo.createRecord")
      .to_return(
        status: 200,
        body: { uri: "at://did:plc:test123/app.bsky.feed.post/abc123", cid: "cid-test" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    # Mastodon: create status
    stub_request(:post, "https://mastodon.test/api/v1/statuses")
      .to_return(
        status: 200,
        body: { id: "masto-123", url: "https://mastodon.test/@user/masto-123" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    # LinkedIn: create post (no images, but may fetch OG for link preview)
    stub_request(:post, "https://api.linkedin.com/rest/posts")
      .to_return(
        status: 201,
        body: "",
        headers: { "x-restli-id" => "urn:li:share:li-post-123" }
      )

    # LinkedIn may fetch OG metadata and initialize image upload for thumbnail
    stub_request(:post, "https://api.linkedin.com/rest/images")
      .with(query: { "action" => "initializeUpload" })
      .to_return(
        status: 200,
        body: { value: { uploadUrl: "https://upload.linkedin.com/upload/123", image: "urn:li:image:123" } }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    stub_request(:put, "https://upload.linkedin.com/upload/123")
      .to_return(status: 201)

    # Medium: get user + create post
    stub_request(:get, "https://api.medium.com/v1/me")
      .to_return(
        status: 200,
        body: { data: { id: "medium-user-123" } }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    stub_request(:post, "https://api.medium.com/v1/users/medium-user-123/posts")
      .to_return(
        status: 201,
        body: { data: { url: "https://medium.com/@user/test-post-123" } }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    # Dev.to: create article
    stub_request(:post, "https://dev.to/api/articles")
      .to_return(
        status: 200,
        body: { url: "https://dev.to/user/test-post-123" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    # Substack: no HTTP stubs needed (uses :test delivery method)
  end
end
