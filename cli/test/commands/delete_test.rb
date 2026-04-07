# frozen_string_literal: true

require "test_helper"

class DeleteCommandTest < Minitest::Test
  def setup
    @config = Blurt::Config.new(api_url: "http://localhost:3000", api_key: "test-key")
  end

  def test_deletes_post_successfully
    stub_request(:delete, "http://localhost:3000/api/posts/my-post.md")
      .to_return(status: 200, body: { message: "Post deleted" }.to_json, headers: json_headers)

    output = capture_io {
      Blurt::Commands::Delete.new(@config).run(id: "my-post.md")
    }.first

    assert_includes output, "Deleted: my-post.md"
    assert_requested(:delete, "http://localhost:3000/api/posts/my-post.md")
  end

  def test_exits_when_post_not_found
    stub_request(:delete, "http://localhost:3000/api/posts/missing.md")
      .to_return(status: 404, body: { error: "Not found" }.to_json, headers: json_headers)

    err_output = capture_io do
      assert_raises(SystemExit) {
        Blurt::Commands::Delete.new(@config).run(id: "missing.md")
      }
    end.last

    assert_includes err_output, "Post not found: missing.md"
    assert_includes err_output, "blurt queue"
  end

  def test_exits_with_error_when_no_api_key
    no_key_config = Blurt::Config.new(api_url: "http://localhost:3000")

    err_output = capture_io do
      assert_raises(SystemExit) {
        Blurt::Commands::Delete.new(no_key_config).run(id: "my-post.md")
      }
    end.last

    assert_includes err_output, "No API key configured"
    assert_includes err_output, "blurt config set api_key"
  end

  def test_exits_with_error_on_auth_failure
    stub_request(:delete, "http://localhost:3000/api/posts/my-post.md")
      .to_return(status: 401, body: { error: "Unauthorized" }.to_json, headers: json_headers)

    err_output = capture_io do
      assert_raises(SystemExit) {
        Blurt::Commands::Delete.new(@config).run(id: "my-post.md")
      }
    end.last

    assert_includes err_output, "Invalid API key"
  end

  def test_exits_with_error_on_connection_failure
    stub_request(:delete, "http://localhost:3000/api/posts/my-post.md")
      .to_raise(Faraday::ConnectionFailed.new("Connection refused"))

    err_output = capture_io do
      assert_raises(SystemExit) {
        Blurt::Commands::Delete.new(@config).run(id: "my-post.md")
      }
    end.last

    assert_includes err_output, "Cannot connect to"
    assert_includes err_output, "Is the Blurt server running"
  end

  private

  def json_headers
    { "Content-Type" => "application/json" }
  end
end
