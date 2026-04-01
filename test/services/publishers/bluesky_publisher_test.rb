# frozen_string_literal: true

require "test_helper"

class Publishers::BlueskyPublisherTest < ActiveSupport::TestCase
  setup do
    @config = {
      service: "https://bsky.social",
      identifier: "user.bsky.social",
      password: "app-password"
    }
    @post = Post.new(
      content: "Hello from blurt! Check https://blurt.sh #OpenSource",
      filename: "test.md",
      platforms: %w[bluesky]
    )
    @session = {
      "did" => "did:plc:abc123",
      "accessJwt" => "jwt-token-123"
    }

    stub_create_session
    # Stub OG metadata fetch for the default post's URL
    stub_og_metadata("https://blurt.sh")
  end

  # --- Publishing flow ---

  test "publishes post and returns Bluesky URL" do
    stub_create_record

    result = Publishers::BlueskyPublisher.publish(@post, config: @config)

    assert_match %r{https://bsky\.app/profile/did:plc:abc123/post/}, result[:url]
    assert_kind_of Time, result[:published_at]
  end

  test "creates session before posting" do
    stub_create_record

    Publishers::BlueskyPublisher.publish(@post, config: @config)

    assert_requested(:post, "https://bsky.social/xrpc/com.atproto.server.createSession") do |req|
      body = JSON.parse(req.body)
      body["identifier"] == "user.bsky.social" && body["password"] == "app-password"
    end
  end

  test "raises when post exceeds 300 char limit" do
    long_post = Post.new(
      content: "a" * 301,
      filename: "long.md",
      platforms: %w[bluesky]
    )

    assert_raises(RuntimeError, /exceeds Bluesky 300-char limit/) do
      Publishers::BlueskyPublisher.publish(long_post, config: @config)
    end
  end

  # --- Rich text facets ---

  test "detects URL facets with correct byte offsets" do
    post = Post.new(
      content: "Visit https://blurt.sh today",
      filename: "url.md",
      platforms: %w[bluesky]
    )

    stub_create_record

    Publishers::BlueskyPublisher.publish(post, config: @config)

    assert_requested(:post, "https://bsky.social/xrpc/com.atproto.repo.createRecord") do |req|
      body = JSON.parse(req.body)
      facets = body.dig("record", "facets")
      next false unless facets

      link_facet = facets.find { |f| f["features"]&.any? { |feat| feat["$type"] == "app.bsky.richtext.facet#link" } }
      next false unless link_facet

      link_facet["features"].first["uri"] == "https://blurt.sh"
    end
  end

  test "detects hashtag facets" do
    post = Post.new(
      content: "Hello #OpenSource #FOSS",
      filename: "tags.md",
      platforms: %w[bluesky]
    )

    stub_create_record

    Publishers::BlueskyPublisher.publish(post, config: @config)

    assert_requested(:post, "https://bsky.social/xrpc/com.atproto.repo.createRecord") do |req|
      body = JSON.parse(req.body)
      facets = body.dig("record", "facets") || []
      tag_facets = facets.select { |f| f["features"]&.any? { |feat| feat["$type"] == "app.bsky.richtext.facet#tag" } }
      tags = tag_facets.flat_map { |f| f["features"].map { |feat| feat["tag"] } }
      tags.include?("OpenSource") && tags.include?("FOSS")
    end
  end

  test "detects mention facets and resolves DID" do
    post = Post.new(
      content: "cc @fberrez.co",
      filename: "mention.md",
      platforms: %w[bluesky]
    )

    stub_request(:get, "https://bsky.social/xrpc/com.atproto.identity.resolveHandle")
      .with(query: { handle: "fberrez.co" })
      .to_return(
        status: 200,
        body: { did: "did:plc:mention123" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    # fberrez.co is also detected as a bare domain for link embed
    stub_og_metadata("https://fberrez.co")
    stub_create_record

    Publishers::BlueskyPublisher.publish(post, config: @config)

    assert_requested(:post, "https://bsky.social/xrpc/com.atproto.repo.createRecord") do |req|
      body = JSON.parse(req.body)
      facets = body.dig("record", "facets") || []
      mention_facets = facets.select { |f| f["features"]&.any? { |feat| feat["$type"] == "app.bsky.richtext.facet#mention" } }
      mention_facets.any? { |f| f["features"].first["did"] == "did:plc:mention123" }
    end
  end

  test "detects bare domain facets" do
    post = Post.new(
      content: "Check blurt.sh for more",
      filename: "bare.md",
      platforms: %w[bluesky]
    )

    stub_create_record
    stub_og_metadata("https://blurt.sh")

    Publishers::BlueskyPublisher.publish(post, config: @config)

    assert_requested(:post, "https://bsky.social/xrpc/com.atproto.repo.createRecord") do |req|
      body = JSON.parse(req.body)
      facets = body.dig("record", "facets") || []
      link_facets = facets.select { |f| f["features"]&.any? { |feat| feat["$type"] == "app.bsky.richtext.facet#link" } }
      link_facets.any? { |f| f["features"].first["uri"] == "https://blurt.sh" }
    end
  end

  # --- Image upload ---

  test "uploads images via uploadBlob" do
    stub_request(:post, "https://bsky.social/xrpc/com.atproto.repo.uploadBlob")
      .to_return(
        status: 200,
        body: { blob: { "$type" => "blob", ref: { "$link" => "bafk123" } } }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    stub_create_record

    images = [ {
      io: StringIO.new("fake-image-data"),
      filename: "photo.jpg",
      alt: "A photo",
      mime_type: "image/jpeg",
      byte_size: 100
    } ]

    Publishers::BlueskyPublisher.publish(@post, config: @config, images: images)

    assert_requested(:post, "https://bsky.social/xrpc/com.atproto.repo.uploadBlob")
    assert_requested(:post, "https://bsky.social/xrpc/com.atproto.repo.createRecord") do |req|
      body = JSON.parse(req.body)
      embed = body.dig("record", "embed")
      embed && embed["$type"] == "app.bsky.embed.images"
    end
  end

  # --- Link preview ---

  test "attaches link embed when no images" do
    post = Post.new(
      content: "Read https://blurt.sh/docs",
      filename: "link.md",
      platforms: %w[bluesky]
    )

    stub_og_metadata("https://blurt.sh/docs", title: "Blurt Docs", description: "Documentation")
    stub_create_record

    Publishers::BlueskyPublisher.publish(post, config: @config)

    assert_requested(:post, "https://bsky.social/xrpc/com.atproto.repo.createRecord") do |req|
      body = JSON.parse(req.body)
      embed = body.dig("record", "embed")
      embed && embed["$type"] == "app.bsky.embed.external" &&
        embed.dig("external", "title") == "Blurt Docs"
    end
  end

  private

  def stub_create_session
    stub_request(:post, "https://bsky.social/xrpc/com.atproto.server.createSession")
      .to_return(
        status: 200,
        body: @session.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def stub_create_record
    stub_request(:post, "https://bsky.social/xrpc/com.atproto.repo.createRecord")
      .to_return(
        status: 200,
        body: { uri: "at://did:plc:abc123/app.bsky.feed.post/3abc123", cid: "cid123" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def stub_og_metadata(url, title: "Page Title", description: "Desc")
    stub_request(:get, url)
      .to_return(
        status: 200,
        body: "<html><head><meta property=\"og:title\" content=\"#{title}\"><meta property=\"og:description\" content=\"#{description}\"></head></html>"
      )
  end
end
