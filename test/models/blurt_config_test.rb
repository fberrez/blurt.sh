# frozen_string_literal: true

require "test_helper"

class BlurtConfigTest < ActiveSupport::TestCase
  setup do
    @original_env = ENV.to_h
  end

  teardown do
    ENV.replace(@original_env)
  end

  # --- Bluesky ---

  test "bluesky returns config when both env vars set" do
    ENV["BLUESKY_IDENTIFIER"] = "user.bsky.social"
    ENV["BLUESKY_PASSWORD"] = "app-password"

    config = BlurtConfig.bluesky
    assert_equal "user.bsky.social", config[:identifier]
    assert_equal "app-password", config[:password]
    assert_equal "https://bsky.social", config[:service]
  end

  test "bluesky returns nil when identifier missing" do
    ENV.delete("BLUESKY_IDENTIFIER")
    ENV["BLUESKY_PASSWORD"] = "pass"

    assert_nil BlurtConfig.bluesky
  end

  test "bluesky uses custom service URL" do
    ENV["BLUESKY_IDENTIFIER"] = "user"
    ENV["BLUESKY_PASSWORD"] = "pass"
    ENV["BLUESKY_SERVICE"] = "https://custom.bsky.social"

    assert_equal "https://custom.bsky.social", BlurtConfig.bluesky[:service]
  end

  # --- Mastodon ---

  test "mastodon returns config when both env vars set" do
    ENV["MASTODON_URL"] = "https://mastodon.social"
    ENV["MASTODON_ACCESS_TOKEN"] = "token-123"

    config = BlurtConfig.mastodon
    assert_equal "https://mastodon.social", config[:url]
    assert_equal "token-123", config[:access_token]
  end

  test "mastodon returns nil when url missing" do
    ENV.delete("MASTODON_URL")
    ENV["MASTODON_ACCESS_TOKEN"] = "token"

    assert_nil BlurtConfig.mastodon
  end

  # --- LinkedIn ---

  test "linkedin returns config when required env vars set" do
    ENV["LINKEDIN_ACCESS_TOKEN"] = "li-token"
    ENV["LINKEDIN_PERSON_ID"] = "person-123"

    config = BlurtConfig.linkedin
    assert_equal "li-token", config[:access_token]
    assert_equal "person-123", config[:person_id]
  end

  test "linkedin returns nil when access token missing" do
    ENV.delete("LINKEDIN_ACCESS_TOKEN")
    ENV["LINKEDIN_PERSON_ID"] = "person"

    assert_nil BlurtConfig.linkedin
  end

  # --- Medium ---

  test "medium returns config when token set" do
    ENV["MEDIUM_INTEGRATION_TOKEN"] = "med-token"

    assert_equal({ integration_token: "med-token" }, BlurtConfig.medium)
  end

  test "medium returns nil when token missing" do
    ENV.delete("MEDIUM_INTEGRATION_TOKEN")
    assert_nil BlurtConfig.medium
  end

  # --- Dev.to ---

  test "devto returns config when api key set" do
    ENV["DEVTO_API_KEY"] = "devto-key"

    assert_equal({ api_key: "devto-key" }, BlurtConfig.devto)
  end

  test "devto returns nil when api key missing" do
    ENV.delete("DEVTO_API_KEY")
    assert_nil BlurtConfig.devto
  end

  # --- Substack ---

  test "substack returns config when smtp vars set" do
    ENV["SUBSTACK_SMTP_HOST"] = "smtp.gmail.com"
    ENV["SUBSTACK_SMTP_PORT"] = "587"
    ENV["SUBSTACK_SMTP_USER"] = "user@gmail.com"
    ENV["SUBSTACK_SMTP_PASSWORD"] = "pass"
    ENV["SUBSTACK_FROM_ADDRESS"] = "from@example.com"
    ENV["SUBSTACK_TO_ADDRESS"] = "import@substack.com"

    config = BlurtConfig.substack
    assert_equal "smtp.gmail.com", config[:smtp_host]
    assert_equal 587, config[:smtp_port]
    assert_equal "user@gmail.com", config[:smtp_user]
  end

  test "substack returns nil when host missing" do
    ENV.delete("SUBSTACK_SMTP_HOST")
    ENV.delete("SUBSTACK_SMTP_USER")

    assert_nil BlurtConfig.substack
  end

  # --- configured_platforms ---

  test "configured_platforms returns only platforms with complete config" do
    ENV.delete("BLUESKY_IDENTIFIER")
    ENV.delete("MASTODON_URL")
    ENV.delete("LINKEDIN_ACCESS_TOKEN")
    ENV.delete("MEDIUM_INTEGRATION_TOKEN")
    ENV.delete("SUBSTACK_SMTP_HOST")
    ENV.delete("SUBSTACK_SMTP_USER")
    ENV["DEVTO_API_KEY"] = "key"

    assert_equal %w[devto], BlurtConfig.configured_platforms
  end

  # --- platform_configured? ---

  test "platform_configured? returns true for configured platform" do
    ENV["DEVTO_API_KEY"] = "key"
    assert BlurtConfig.platform_configured?(:devto)
  end

  test "platform_configured? returns false for unconfigured platform" do
    ENV.delete("DEVTO_API_KEY")
    refute BlurtConfig.platform_configured?(:devto)
  end

  test "platform_configured? returns false for unknown platform" do
    refute BlurtConfig.platform_configured?(:twitter)
  end

  # --- poll_interval ---

  test "poll_interval defaults to 60000" do
    ENV.delete("POLL_INTERVAL_MS")
    assert_equal 60000, BlurtConfig.poll_interval
  end

  test "poll_interval reads from env" do
    ENV["POLL_INTERVAL_MS"] = "30000"
    assert_equal 30000, BlurtConfig.poll_interval
  end
end
