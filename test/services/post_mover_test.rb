# frozen_string_literal: true

require "test_helper"

class PostMoverTest < ActiveSupport::TestCase
  setup do
    @test_root = Rails.root.join("tmp", "test_mover_#{SecureRandom.hex(4)}")
    @queue_dir = File.join(@test_root, "queue")
    @sent_dir = File.join(@test_root, "sent")
    @failed_dir = File.join(@test_root, "failed")
    FileUtils.mkdir_p([@queue_dir, @sent_dir, @failed_dir])

    # Override constants
    @originals = {
      QUEUE_DIR: PostMover::QUEUE_DIR,
      SENT_DIR: PostMover::SENT_DIR,
      FAILED_DIR: PostMover::FAILED_DIR
    }
    PostMover.send(:remove_const, :QUEUE_DIR)
    PostMover.send(:remove_const, :SENT_DIR)
    PostMover.send(:remove_const, :FAILED_DIR)
    PostMover.const_set(:QUEUE_DIR, @queue_dir)
    PostMover.const_set(:SENT_DIR, @sent_dir)
    PostMover.const_set(:FAILED_DIR, @failed_dir)
  end

  teardown do
    FileUtils.rm_rf(@test_root)
    PostMover.send(:remove_const, :QUEUE_DIR)
    PostMover.send(:remove_const, :SENT_DIR)
    PostMover.send(:remove_const, :FAILED_DIR)
    PostMover.const_set(:QUEUE_DIR, @originals[:QUEUE_DIR])
    PostMover.const_set(:SENT_DIR, @originals[:SENT_DIR])
    PostMover.const_set(:FAILED_DIR, @originals[:FAILED_DIR])
  end

  test "move_to_sent moves file to sent directory" do
    post, source = create_test_post("test.md")

    PostMover.move_to_sent(post, success_results, source_path: source)

    assert_empty Dir.children(@queue_dir)
    sent_files = Dir.children(@sent_dir)
    assert_equal 1, sent_files.length
    assert_includes sent_files.first, "test.md"
  end

  test "move_to_sent enriches frontmatter with publishedAt and results" do
    post, source = create_test_post("enrich.md")

    PostMover.move_to_sent(post, success_results, source_path: source)

    sent_file = Dir.glob(File.join(@sent_dir, "*")).first
    content = File.read(sent_file)
    parsed = FrontMatterParser::Parser.new(:md).call(content)

    assert parsed.front_matter.key?("publishedAt")
    assert parsed.front_matter.key?("results")
    assert parsed.front_matter["results"].key?("bluesky")
    assert_equal "https://bsky.app/profile/did/post/rkey", parsed.front_matter.dig("results", "bluesky", "url")
  end

  test "move_to_sent adds timestamp prefix to filename" do
    post, source = create_test_post("prefixed.md")

    PostMover.move_to_sent(post, success_results, source_path: source)

    sent_file = Dir.children(@sent_dir).first
    # Format: 2026-03-30T14-30-45-123Z_prefixed.md
    assert_match(/\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}-\d{3}Z_prefixed\.md/, sent_file)
  end

  test "move_to_failed moves file to failed directory" do
    post, source = create_test_post("fail.md")
    results = {
      "bluesky" => { error: "Connection refused" }
    }

    PostMover.move_to_failed(post, results, source_path: source)

    assert_empty Dir.children(@queue_dir)
    assert_equal 1, Dir.children(@failed_dir).length
  end

  test "move_to_failed enriches frontmatter with errors and failedAt" do
    post, source = create_test_post("errors.md")
    results = {
      "bluesky" => { url: "https://bsky.app/profile/did/post/rkey", published_at: Time.current },
      "mastodon" => { error: "502 Bad Gateway" }
    }

    PostMover.move_to_failed(post, results, source_path: source)

    failed_file = Dir.glob(File.join(@failed_dir, "*")).first
    content = File.read(failed_file)
    parsed = FrontMatterParser::Parser.new(:md).call(content)

    assert parsed.front_matter.key?("failedAt")
    assert parsed.front_matter.key?("errors")
    assert_equal "502 Bad Gateway", parsed.front_matter.dig("errors", "mastodon")
    # Successful results are also preserved
    assert parsed.front_matter.key?("results")
    assert_equal "https://bsky.app/profile/did/post/rkey", parsed.front_matter.dig("results", "bluesky", "url")
  end

  test "move_to_sent handles .publishing suffix in source path" do
    post, source = create_test_post("locked.md")
    publishing_source = "#{source}.publishing"
    File.rename(source, publishing_source)

    PostMover.move_to_sent(post, success_results, source_path: publishing_source)

    sent_file = Dir.children(@sent_dir).first
    assert_includes sent_file, "locked.md"
    refute_includes sent_file, ".publishing"
  end

  test "move_to_sent handles directory posts" do
    dir = File.join(@queue_dir, "my-post")
    FileUtils.mkdir_p(dir)
    md_path = File.join(dir, "post.md")
    write_md(md_path)

    post = Post.from_file(md_path)

    PostMover.move_to_sent(post, success_results, source_path: dir)

    assert_empty Dir.children(@queue_dir)
    sent_entries = Dir.children(@sent_dir)
    assert_equal 1, sent_entries.length
    assert File.directory?(File.join(@sent_dir, sent_entries.first))
  end

  private

  def create_test_post(filename)
    path = File.join(@queue_dir, filename)
    write_md(path)
    post = Post.from_file(path)
    [ post, path ]
  end

  def write_md(path)
    File.write(path, <<~MD)
      ---
      platforms:
        - bluesky
      ---

      Test content
    MD
  end

  def success_results
    {
      "bluesky" => { url: "https://bsky.app/profile/did/post/rkey", published_at: Time.current }
    }
  end
end
