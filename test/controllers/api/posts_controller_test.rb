# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class Api::PostsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @tmp_dir = Dir.mktmpdir("blurt_api_test")
    @queue_dir = File.join(@tmp_dir, "queue")
    @sent_dir = File.join(@tmp_dir, "sent")
    @failed_dir = File.join(@tmp_dir, "failed")
    FileUtils.mkdir_p([ @queue_dir, @sent_dir, @failed_dir ])

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

    @api_key = "test-api-key-#{SecureRandom.hex(8)}"
    ENV["BLURT_API_KEY"] = @api_key

    # Configure platforms for publish tests
    @env_vars = {
      "BLUESKY_IDENTIFIER" => "test.bsky.social",
      "BLUESKY_PASSWORD" => "test-password",
      "DEVTO_API_KEY" => "devto-key"
    }
    @env_vars.each { |k, v| ENV[k] = v }
  end

  teardown do
    silence_warnings do
      QueueScanner.const_set(:QUEUE_DIR, @original_scanner_dir)
      PostMover.const_set(:QUEUE_DIR, @original_mover_queue)
      PostMover.const_set(:SENT_DIR, @original_mover_sent)
      PostMover.const_set(:FAILED_DIR, @original_mover_failed)
    end
    ENV.delete("BLURT_API_KEY")
    @env_vars.each_key { |k| ENV.delete(k) }
    FileUtils.rm_rf(@tmp_dir)
  end

  # --- Auth ---

  test "returns 401 without authorization header" do
    get api_posts_url
    assert_response :unauthorized
    assert_equal "Unauthorized", JSON.parse(response.body)["error"]
  end

  test "returns 401 with invalid bearer token" do
    get api_posts_url, headers: auth_headers("wrong-key")
    assert_response :unauthorized
  end

  test "returns 503 when BLURT_API_KEY not set" do
    ENV.delete("BLURT_API_KEY")
    get api_posts_url, headers: auth_headers(@api_key)
    assert_response :service_unavailable
  end

  # --- GET /api/posts ---

  test "index returns empty array for empty queue" do
    get api_posts_url, headers: auth_headers
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [], body["posts"]
  end

  test "index returns parsed posts from queue" do
    create_post("hello.md", title: "Hello World", platforms: %w[bluesky], content: "Hello!")

    get api_posts_url, headers: auth_headers
    assert_response :success

    body = JSON.parse(response.body)
    assert_equal 1, body["posts"].length
    post = body["posts"].first
    assert_equal "hello.md", post["filename"]
    assert_equal "Hello World", post["title"]
    assert_equal %w[bluesky], post["platforms"]
    assert_equal "queue", post["status"]
  end

  test "index scans sent directory with status param" do
    create_post("sent-post.md", title: "Sent", platforms: %w[bluesky], content: "Done", dir: @sent_dir)

    get api_posts_url, params: { status: "sent" }, headers: auth_headers
    assert_response :success

    body = JSON.parse(response.body)
    assert_equal 1, body["posts"].length
    assert_equal "sent", body["posts"].first["status"]
  end

  test "index filters by platform" do
    create_post("bsky.md", title: "Bluesky", platforms: %w[bluesky], content: "Sky")
    create_post("devto.md", title: "DevTo", platforms: %w[devto], content: "Dev")

    get api_posts_url, params: { platform: "bluesky" }, headers: auth_headers
    assert_response :success

    body = JSON.parse(response.body)
    assert_equal 1, body["posts"].length
    assert_equal "bsky.md", body["posts"].first["filename"]
  end

  # --- GET /api/posts/:id ---

  test "show returns single post" do
    create_post("my-post.md", title: "My Post", platforms: %w[bluesky], content: "Content")

    get api_post_url("my-post.md"), headers: auth_headers
    assert_response :success

    body = JSON.parse(response.body)
    assert_equal "my-post.md", body["post"]["filename"]
    assert_equal "My Post", body["post"]["title"]
  end

  test "show returns 404 for nonexistent post" do
    get api_post_url("nope.md"), headers: auth_headers
    assert_response :not_found
  end

  test "show finds posts in sent directory" do
    create_post("published.md", title: "Published", platforms: %w[bluesky], content: "Done", dir: @sent_dir)

    get api_post_url("published.md"), headers: auth_headers
    assert_response :success
    assert_equal "sent", JSON.parse(response.body)["post"]["status"]
  end

  # --- POST /api/posts ---

  test "create makes a file in queue with frontmatter" do
    post api_posts_url,
      params: { title: "New Post", platforms: %w[bluesky devto], content: "Hello world" },
      headers: auth_headers,
      as: :json

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "new-post.md", body["post"]["filename"]
    assert_equal "New Post", body["post"]["title"]
    assert_equal %w[bluesky devto], body["post"]["platforms"]

    # Verify file exists
    assert File.exist?(File.join(@queue_dir, "new-post.md"))
  end

  test "create with explicit filename" do
    post api_posts_url,
      params: { filename: "custom.md", platforms: %w[bluesky], content: "Custom" },
      headers: auth_headers,
      as: :json

    assert_response :created
    assert_equal "custom.md", JSON.parse(response.body)["post"]["filename"]
    assert File.exist?(File.join(@queue_dir, "custom.md"))
  end

  test "create returns 409 for duplicate filename" do
    create_post("dupe.md", platforms: %w[bluesky], content: "First")

    post api_posts_url,
      params: { filename: "dupe.md", platforms: %w[bluesky], content: "Second" },
      headers: auth_headers,
      as: :json

    assert_response :conflict
  end

  # --- PUT /api/posts/:id ---

  test "update modifies post frontmatter and content" do
    create_post("editable.md", title: "Original", platforms: %w[bluesky], content: "Old content")

    put api_post_url("editable.md"),
      params: { title: "Updated", content: "New content" },
      headers: auth_headers,
      as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "Updated", body["post"]["title"]
    assert_equal "New content", body["post"]["content"]
  end

  test "update returns 404 for nonexistent post" do
    put api_post_url("nope.md"),
      params: { title: "Updated" },
      headers: auth_headers,
      as: :json

    assert_response :not_found
  end

  # --- DELETE /api/posts/:id ---

  test "destroy removes post from queue" do
    create_post("deleteme.md", platforms: %w[bluesky], content: "Bye")

    delete api_post_url("deleteme.md"), headers: auth_headers
    assert_response :success
    assert_not File.exist?(File.join(@queue_dir, "deleteme.md"))
  end

  test "destroy returns 404 for nonexistent post" do
    delete api_post_url("nope.md"), headers: auth_headers
    assert_response :not_found
  end

  # --- POST /api/posts/:id/publish ---

  test "publish triggers immediate publish" do
    create_post("publish-me.md", title: "Publish Test", platforms: %w[devto], content: "Publish this")

    stub_request(:post, "https://dev.to/api/articles")
      .to_return(
        status: 200,
        body: { url: "https://dev.to/user/publish-test" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    post publish_api_post_url("publish-me.md"), headers: auth_headers
    assert_response :success

    body = JSON.parse(response.body)
    assert_equal "sent", body["post"]["status"]
    assert_equal "https://dev.to/user/publish-test", body["post"]["results"]["devto"][:url] || body["post"]["results"]["devto"]["url"]
  end

  test "publish returns 404 for nonexistent post" do
    post publish_api_post_url("nope.md"), headers: auth_headers
    assert_response :not_found
  end

  private

  def auth_headers(key = @api_key)
    { "Authorization" => "Bearer #{key}" }
  end

  def create_post(filename, title: nil, platforms: [], content: "", dir: @queue_dir)
    fm = {}
    fm["title"] = title if title
    fm["platforms"] = platforms if platforms.any?
    file_content = "#{fm.to_yaml}---\n\n#{content}\n"
    File.write(File.join(dir, filename), file_content)
  end
end
