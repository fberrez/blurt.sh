# frozen_string_literal: true

require "test_helper"
require "json"

class DeletePostToolTest < Minitest::Test
  def setup
    @server = build_server
  end

  def test_success
    stub_request(:delete, "http://localhost:3000/api/posts/hello.md")
      .to_return(status: 204, body: "", headers: json_headers)

    result = call_tool(@server, "delete-post", { id: "hello.md" })
    assert_equal false, result["isError"]
    assert_includes result["content"].first["text"], "Deleted hello.md."
  end

  def test_not_found
    stub_request(:delete, "http://localhost:3000/api/posts/missing.md")
      .to_return(status: 404, body: { error: "Not found" }.to_json, headers: json_headers)

    result = call_tool(@server, "delete-post", { id: "missing.md" })
    assert_equal true, result["isError"]
    assert_includes result["content"].first["text"], "Not found: missing.md"
  end
end
