# frozen_string_literal: true

require "test_helper"

class Publishers::MastodonPublisherTest < ActiveSupport::TestCase
  setup do
    @config = {
      url: "https://mastodon.social",
      access_token: "masto-token-123"
    }
    @post = Post.new(
      content: "Hello from blurt!",
      filename: "test.md",
      platforms: %w[mastodon]
    )
  end

  test "publishes status and returns URL" do
    stub_create_status

    result = Publishers::MastodonPublisher.publish(@post, config: @config)

    assert_equal "https://mastodon.social/@user/123456", result[:url]
    assert_kind_of Time, result[:published_at]
  end

  test "sends Bearer token auth" do
    stub_create_status

    Publishers::MastodonPublisher.publish(@post, config: @config)

    assert_requested(:post, "https://mastodon.social/api/v1/statuses",
      headers: { "Authorization" => "Bearer masto-token-123" })
  end

  test "sends plaintext content as status" do
    post = Post.new(
      content: "**bold** and [link](https://example.com)",
      filename: "md.md",
      platforms: %w[mastodon]
    )

    stub_create_status

    Publishers::MastodonPublisher.publish(post, config: @config)

    assert_requested(:post, "https://mastodon.social/api/v1/statuses") do |req|
      body = JSON.parse(req.body)
      # Should be plaintext, not markdown
      !body["status"].include?("**") && !body["status"].include?("[link]")
    end
  end

  test "prepends https:// to bare domains" do
    post = Post.new(
      content: "Check blurt.sh for details",
      filename: "bare.md",
      platforms: %w[mastodon]
    )

    stub_create_status

    Publishers::MastodonPublisher.publish(post, config: @config)

    assert_requested(:post, "https://mastodon.social/api/v1/statuses") do |req|
      body = JSON.parse(req.body)
      body["status"].include?("https://blurt.sh")
    end
  end

  test "does not double-prefix existing https URLs" do
    post = Post.new(
      content: "Visit https://blurt.sh today",
      filename: "full.md",
      platforms: %w[mastodon]
    )

    stub_create_status

    Publishers::MastodonPublisher.publish(post, config: @config)

    assert_requested(:post, "https://mastodon.social/api/v1/statuses") do |req|
      body = JSON.parse(req.body)
      !body["status"].include?("https://https://")
    end
  end

  test "raises when post exceeds 500 char limit" do
    long_post = Post.new(
      content: "a" * 501,
      filename: "long.md",
      platforms: %w[mastodon]
    )

    assert_raises(RuntimeError, /exceeds Mastodon 500-char limit/) do
      Publishers::MastodonPublisher.publish(long_post, config: @config)
    end
  end

  test "uploads images via multipart media endpoint" do
    stub_request(:post, "https://mastodon.social/api/v2/media")
      .to_return(
        status: 200,
        body: { id: "media-789" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    stub_request(:post, "https://mastodon.social/api/v1/statuses")
      .to_return(
        status: 200,
        body: { url: "https://mastodon.social/@user/999" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    images = [{
      io: StringIO.new("fake-image"),
      filename: "photo.jpg",
      alt: "A photo",
      mime_type: "image/jpeg",
      byte_size: 100
    } ]

    result = Publishers::MastodonPublisher.publish(@post, config: @config, images: images)

    assert_requested(:post, "https://mastodon.social/api/v2/media")
    assert_requested(:post, "https://mastodon.social/api/v1/statuses") do |req|
      body = JSON.parse(req.body)
      body["media_ids"]&.include?("media-789")
    end
  end

  test "raises on API error" do
    stub_request(:post, "https://mastodon.social/api/v1/statuses")
      .to_return(status: 422, body: { error: "Validation failed" }.to_json)

    assert_raises(Faraday::UnprocessableEntityError) do
      Publishers::MastodonPublisher.publish(@post, config: @config)
    end
  end

  private

  def stub_create_status
    stub_request(:post, "https://mastodon.social/api/v1/statuses")
      .to_return(
        status: 200,
        body: { url: "https://mastodon.social/@user/123456" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end
end
