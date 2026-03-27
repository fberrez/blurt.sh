# frozen_string_literal: true

require "test_helper"

class Publishers::DevtoPublisherTest < ActiveSupport::TestCase
  setup do
    @config = { api_key: "test-api-key" }
    @post = Post.new(
      title: "Test Article",
      content: "# Hello\n\nThis is a test.",
      filename: "test.md",
      platforms: %w[devto]
    )
  end

  test "publishes article and returns URL" do
    stub_request(:post, "https://dev.to/api/articles")
      .to_return(
        status: 200,
        body: { url: "https://dev.to/user/test-article-abc" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = Publishers::DevtoPublisher.publish(@post, config: @config)

    assert_equal "https://dev.to/user/test-article-abc", result[:url]
    assert_kind_of Time, result[:published_at]
  end

  test "sends raw markdown as body_markdown" do
    stub_request(:post, "https://dev.to/api/articles")
      .to_return(
        status: 200,
        body: { url: "https://dev.to/user/x" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    Publishers::DevtoPublisher.publish(@post, config: @config)

    assert_requested(:post, "https://dev.to/api/articles") do |req|
      body = JSON.parse(req.body)
      body.dig("article", "body_markdown") == "# Hello\n\nThis is a test." &&
        body.dig("article", "title") == "Test Article" &&
        body.dig("article", "published") == true
    end
  end

  test "sends api-key header" do
    stub_request(:post, "https://dev.to/api/articles")
      .with(headers: { "api-key" => "test-api-key" })
      .to_return(
        status: 200,
        body: { url: "https://dev.to/user/x" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    Publishers::DevtoPublisher.publish(@post, config: @config)

    assert_requested(:post, "https://dev.to/api/articles",
      headers: { "api-key" => "test-api-key" })
  end

  test "raises on API error" do
    stub_request(:post, "https://dev.to/api/articles")
      .to_return(status: 422, body: { error: "Validation failed" }.to_json)

    assert_raises(Faraday::UnprocessableEntityError) do
      Publishers::DevtoPublisher.publish(@post, config: @config)
    end
  end
end
