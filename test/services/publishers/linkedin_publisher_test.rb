# frozen_string_literal: true

require "test_helper"

class Publishers::LinkedinPublisherTest < ActiveSupport::TestCase
  setup do
    @config = {
      access_token: "li-token-123",
      person_id: "person-abc"
    }
    @post = Post.new(
      content: "Hello from blurt! Check https://blurt.sh",
      filename: "test.md",
      platforms: %w[linkedin]
    )
  end

  test "publishes post and returns LinkedIn URL" do
    stub_create_post
    stub_og_metadata("https://blurt.sh")

    result = Publishers::LinkedinPublisher.publish(@post, config: @config)

    assert_equal "https://www.linkedin.com/feed/update/urn:li:share:123", result[:url]
    assert_kind_of Time, result[:published_at]
  end

  test "sends correct auth headers" do
    stub_create_post
    stub_og_metadata("https://blurt.sh")

    Publishers::LinkedinPublisher.publish(@post, config: @config)

    assert_requested(:post, "https://api.linkedin.com/rest/posts") do |req|
      req.headers["Authorization"] == "Bearer li-token-123" &&
        req.headers["X-Restli-Protocol-Version"] == "2.0.0"
    end
  end

  test "sets author URN from person_id" do
    stub_create_post
    stub_og_metadata("https://blurt.sh")

    Publishers::LinkedinPublisher.publish(@post, config: @config)

    assert_requested(:post, "https://api.linkedin.com/rest/posts") do |req|
      body = JSON.parse(req.body)
      body["author"] == "urn:li:person:person-abc"
    end
  end

  test "raises descriptive error on 401 token expiry" do
    stub_request(:post, "https://api.linkedin.com/rest/posts")
      .to_return(status: 401, body: { message: "Unauthorized" }.to_json)

    # Need to also stub the OG fetch since it happens before the post
    stub_og_metadata("https://blurt.sh")

    error = assert_raises(RuntimeError) do
      Publishers::LinkedinPublisher.publish(@post, config: @config)
    end

    assert_includes error.message, "LinkedIn token expired"
    assert_includes error.message, "rake blurt:linkedin_auth"
  end

  test "uploads images via two-step flow" do
    stub_request(:post, "https://api.linkedin.com/rest/images?action=initializeUpload")
      .to_return(
        status: 200,
        body: { value: { uploadUrl: "https://upload.linkedin.com/put-here", image: "urn:li:image:123" } }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    stub_request(:put, "https://upload.linkedin.com/put-here")
      .to_return(status: 201)

    stub_create_post

    images = [{
      io: StringIO.new("fake-image-data"),
      filename: "photo.jpg",
      alt: "A photo",
      mime_type: "image/jpeg",
      byte_size: 100
    } ]

    Publishers::LinkedinPublisher.publish(@post, config: @config, images: images)

    assert_requested(:post, "https://api.linkedin.com/rest/images?action=initializeUpload")
    assert_requested(:put, "https://upload.linkedin.com/put-here")
    assert_requested(:post, "https://api.linkedin.com/rest/posts") do |req|
      body = JSON.parse(req.body)
      body.dig("content", "media", "id") == "urn:li:image:123"
    end
  end

  test "attaches link preview with OG metadata when no images" do
    stub_og_metadata("https://blurt.sh", title: "Blurt", description: "Publish everywhere")
    stub_create_post

    Publishers::LinkedinPublisher.publish(@post, config: @config)

    assert_requested(:post, "https://api.linkedin.com/rest/posts") do |req|
      body = JSON.parse(req.body)
      article = body.dig("content", "article")
      article && article["source"] == "https://blurt.sh" && article["title"] == "Blurt"
    end
  end

  test "sends plaintext content as commentary" do
    post = Post.new(
      content: "**bold** text with [link](https://example.com)",
      filename: "md.md",
      platforms: %w[linkedin]
    )

    stub_create_post
    stub_og_metadata("https://example.com")

    Publishers::LinkedinPublisher.publish(post, config: @config)

    assert_requested(:post, "https://api.linkedin.com/rest/posts") do |req|
      body = JSON.parse(req.body)
      !body["commentary"].include?("**") && !body["commentary"].include?("[link]")
    end
  end

  private

  def stub_create_post
    stub_request(:post, "https://api.linkedin.com/rest/posts")
      .to_return(
        status: 201,
        body: "".to_json,
        headers: {
          "Content-Type" => "application/json",
          "x-restli-id" => "urn:li:share:123"
        }
      )
  end

  def stub_og_metadata(url, title: "Page", description: "Desc")
    stub_request(:get, url)
      .to_return(
        status: 200,
        body: "<html><head><meta property=\"og:title\" content=\"#{title}\"><meta property=\"og:description\" content=\"#{description}\"></head></html>"
      )
  end
end
