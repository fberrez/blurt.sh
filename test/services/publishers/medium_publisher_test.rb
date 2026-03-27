# frozen_string_literal: true

require "test_helper"

class Publishers::MediumPublisherTest < ActiveSupport::TestCase
  setup do
    @config = { integration_token: "test-medium-token" }
    @post = Post.new(
      title: "My Medium Article",
      content: "# Hello\n\nThis is **bold** text.",
      filename: "test.md",
      platforms: %w[medium]
    )
  end

  test "publishes article via two-step flow and returns URL" do
    stub_request(:get, "https://api.medium.com/v1/me")
      .to_return(
        status: 200,
        body: { data: { id: "user-123" } }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    stub_request(:post, "https://api.medium.com/v1/users/user-123/posts")
      .to_return(
        status: 201,
        body: { data: { url: "https://medium.com/@user/my-article-abc123" } }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = Publishers::MediumPublisher.publish(@post, config: @config)

    assert_equal "https://medium.com/@user/my-article-abc123", result[:url]
    assert_kind_of Time, result[:published_at]
  end

  test "sends HTML content, not raw markdown" do
    stub_request(:get, "https://api.medium.com/v1/me")
      .to_return(
        status: 200,
        body: { data: { id: "user-123" } }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    stub_request(:post, "https://api.medium.com/v1/users/user-123/posts")
      .to_return(
        status: 201,
        body: { data: { url: "https://medium.com/@user/x" } }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    Publishers::MediumPublisher.publish(@post, config: @config)

    assert_requested(:post, "https://api.medium.com/v1/users/user-123/posts") do |req|
      body = JSON.parse(req.body)
      body["contentFormat"] == "html" &&
        body["publishStatus"] == "public" &&
        body["title"] == "My Medium Article" &&
        body["content"].include?("<strong>bold</strong>")
    end
  end

  test "sends Bearer token auth" do
    stub_request(:get, "https://api.medium.com/v1/me")
      .with(headers: { "Authorization" => "Bearer test-medium-token" })
      .to_return(
        status: 200,
        body: { data: { id: "user-123" } }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    stub_request(:post, "https://api.medium.com/v1/users/user-123/posts")
      .to_return(
        status: 201,
        body: { data: { url: "https://medium.com/@user/x" } }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    Publishers::MediumPublisher.publish(@post, config: @config)

    assert_requested(:get, "https://api.medium.com/v1/me",
      headers: { "Authorization" => "Bearer test-medium-token" })
  end

  test "raises on API error" do
    stub_request(:get, "https://api.medium.com/v1/me")
      .to_return(status: 401, body: { errors: [{ message: "Token invalid" }] }.to_json)

    assert_raises(Faraday::UnauthorizedError) do
      Publishers::MediumPublisher.publish(@post, config: @config)
    end
  end
end
