# frozen_string_literal: true

require "test_helper"
require "json"

class PlatformsResourceTest < Minitest::Test
  def setup
    @server = build_server
  end

  def test_listed_in_resources_list
    result = list_resources(@server)
    uris = result["resources"].map { |r| r["uri"] }
    assert_includes uris, "blurt://platforms"
  end

  def test_read_returns_json_payload
    stub_request(:get, "http://localhost:3000/api/platforms")
      .to_return(status: 200, body: {
        platforms: [
          { name: "bluesky", type: "social" },
          { name: "mastodon", type: "social" }
        ]
      }.to_json, headers: json_headers)

    result = read_resource(@server, "blurt://platforms")
    payload = JSON.parse(result["contents"].first["text"])
    assert_equal 2, payload["count"]
    names = payload["platforms"].map { |p| p["name"] }.sort
    assert_equal %w[bluesky mastodon], names
  end
end
