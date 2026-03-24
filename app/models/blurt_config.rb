# frozen_string_literal: true

class BlurtConfig
  PLATFORMS = %w[bluesky mastodon linkedin medium devto substack].freeze

  class << self
    def bluesky
      return nil unless ENV["BLUESKY_IDENTIFIER"] && ENV["BLUESKY_PASSWORD"]

      {
        service: ENV.fetch("BLUESKY_SERVICE", "https://bsky.social"),
        identifier: ENV.fetch("BLUESKY_IDENTIFIER"),
        password: ENV.fetch("BLUESKY_PASSWORD")
      }
    end

    def mastodon
      return nil unless ENV["MASTODON_URL"] && ENV["MASTODON_ACCESS_TOKEN"]

      {
        url: ENV.fetch("MASTODON_URL"),
        access_token: ENV.fetch("MASTODON_ACCESS_TOKEN")
      }
    end

    def linkedin
      return nil unless ENV["LINKEDIN_ACCESS_TOKEN"] && ENV["LINKEDIN_PERSON_ID"]

      {
        access_token: ENV.fetch("LINKEDIN_ACCESS_TOKEN"),
        person_id: ENV.fetch("LINKEDIN_PERSON_ID"),
        client_id: ENV["LINKEDIN_CLIENT_ID"],
        client_secret: ENV["LINKEDIN_CLIENT_SECRET"]
      }
    end

    def medium
      return nil unless ENV["MEDIUM_INTEGRATION_TOKEN"]

      { integration_token: ENV.fetch("MEDIUM_INTEGRATION_TOKEN") }
    end

    def devto
      return nil unless ENV["DEVTO_API_KEY"]

      { api_key: ENV.fetch("DEVTO_API_KEY") }
    end

    def substack
      return nil unless ENV["SUBSTACK_SMTP_HOST"] && ENV["SUBSTACK_SMTP_USER"]

      {
        smtp_host: ENV.fetch("SUBSTACK_SMTP_HOST"),
        smtp_port: ENV.fetch("SUBSTACK_SMTP_PORT", "587").to_i,
        smtp_user: ENV.fetch("SUBSTACK_SMTP_USER"),
        smtp_password: ENV.fetch("SUBSTACK_SMTP_PASSWORD"),
        from_address: ENV.fetch("SUBSTACK_FROM_ADDRESS"),
        to_address: ENV.fetch("SUBSTACK_TO_ADDRESS")
      }
    end

    def configured_platforms
      PLATFORMS.select { |platform| send(platform).present? }
    end

    def platform_configured?(platform)
      PLATFORMS.include?(platform.to_s) && send(platform).present?
    end

    def poll_interval
      ENV.fetch("POLL_INTERVAL_MS", "60000").to_i
    end
  end
end
