# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "zip"

class Api::ExportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @tmp_dir = Dir.mktmpdir("blurt_export_test")
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

  test "returns ZIP with sent files" do
    File.write(File.join(@sent_dir, "post1.md"), "---\ntitle: Post 1\n---\nContent 1")
    File.write(File.join(@sent_dir, "post2.md"), "---\ntitle: Post 2\n---\nContent 2")

    get api_export_url, headers: auth_headers
    assert_response :success
    assert_equal "application/zip", response.content_type

    # Verify ZIP contents
    zip_io = StringIO.new(response.body)
    entries = []
    Zip::InputStream.open(zip_io) do |io|
      while (entry = io.get_next_entry)
        entries << entry.name
      end
    end

    assert_includes entries, "post1.md"
    assert_includes entries, "post2.md"
  end

  test "returns 404 when no sent files exist" do
    get api_export_url, headers: auth_headers
    assert_response :not_found
  end

  test "requires authentication" do
    get api_export_url
    assert_response :unauthorized
  end

  private

  def auth_headers
    { "Authorization" => "Bearer #{@api_key}" }
  end
end
