# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class Api::HealthControllerTest < ActionDispatch::IntegrationTest
  setup do
    @tmp_dir = Dir.mktmpdir("blurt_health_test")
    @queue_dir = File.join(@tmp_dir, "queue")
    @sent_dir = File.join(@tmp_dir, "sent")
    @failed_dir = File.join(@tmp_dir, "failed")
    FileUtils.mkdir_p([ @queue_dir, @sent_dir, @failed_dir ])

    @original_scanner_dir = QueueScanner::QUEUE_DIR
    @original_mover_sent = PostMover::SENT_DIR
    @original_mover_failed = PostMover::FAILED_DIR

    silence_warnings do
      QueueScanner.const_set(:QUEUE_DIR, @queue_dir)
      PostMover.const_set(:SENT_DIR, @sent_dir)
      PostMover.const_set(:FAILED_DIR, @failed_dir)
    end
  end

  teardown do
    silence_warnings do
      QueueScanner.const_set(:QUEUE_DIR, @original_scanner_dir)
      PostMover.const_set(:SENT_DIR, @original_mover_sent)
      PostMover.const_set(:FAILED_DIR, @original_mover_failed)
    end
    FileUtils.rm_rf(@tmp_dir)
  end

  test "returns 200 without authentication" do
    get api_health_url
    assert_response :success
  end

  test "returns queue counts" do
    File.write(File.join(@queue_dir, "post1.md"), "---\nplatforms:\n  - bluesky\n---\nHello")
    File.write(File.join(@queue_dir, "post2.md"), "---\nplatforms:\n  - bluesky\n---\nWorld")
    File.write(File.join(@sent_dir, "sent1.md"), "---\n---\nSent")

    get api_health_url
    assert_response :success

    body = JSON.parse(response.body)
    assert_equal 2, body["queue"]["pending"]
    assert_equal 1, body["sent"]["total"]
    assert_equal 0, body["failed"]["total"]
    assert_equal "ok", body["status"]
  end

  test "returns platform configuration" do
    get api_health_url
    body = JSON.parse(response.body)

    assert body.key?("platforms")
    assert_kind_of Array, body["platforms"]["configured"]
    assert_kind_of Integer, body["platforms"]["count"]
  end
end
