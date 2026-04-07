# frozen_string_literal: true

require "thor"

module Blurt
  class CLI < Thor
    class_option :api_url, type: :string, desc: "Blurt API URL (default: $BLURT_API_URL or http://localhost:3000)"
    class_option :api_key, type: :string, desc: "Blurt API key (default: $BLURT_API_KEY)"

    desc "status", "Show server health and queue status"
    def status
      Commands::Status.new(build_config).run
    end

    desc "queue", "List queued posts"
    option :status, type: :string, default: "queue", desc: "Filter: queue, sent, failed, all"
    option :platform, type: :string, desc: "Filter by platform"
    def queue
      Commands::Queue.new(build_config).run(
        status: options[:status],
        platform: options[:platform]
      )
    end

    desc "post [CONTENT]", "Create a new post"
    option :file, type: :string, aliases: "-f", desc: "Read content from a markdown file"
    option :platforms, type: :string, aliases: "-p", desc: "Comma-separated platforms (e.g. bluesky,mastodon)"
    option :title, type: :string, aliases: "-t", desc: "Post title (required for blog platforms)"
    option :scheduled_at, type: :string, desc: "Schedule publish time (ISO 8601)"
    def post(content = nil)
      platforms = options[:platforms]&.split(",")&.map(&:strip)
      Commands::Post.new(build_config).run(
        content: content,
        file: options[:file],
        platforms: platforms,
        title: options[:title],
        scheduled_at: options[:scheduled_at]
      )
    end

    desc "publish ID", "Publish a queued post immediately"
    def publish(id)
      Commands::Publish.new(build_config).run(id: id)
    end

    desc "history", "List published posts"
    option :page, type: :numeric, desc: "Page number"
    option :platform, type: :string, desc: "Filter by platform"
    def history
      Commands::History.new(build_config).run(
        page: options[:page],
        platform: options[:platform]
      )
    end

    desc "delete ID", "Delete a queued post"
    def delete(id)
      Commands::Delete.new(build_config).run(id: id)
    end

    desc "version", "Print blurt version"
    def version
      puts "blurt #{Blurt::VERSION}"
    end

    map %w[-v --version] => :version

    desc "config SUBCOMMAND", "Manage configuration (api_url, api_key)"
    subcommand "config", Blurt::ConfigCLI

    private

    def build_config
      Config.new(
        api_url: options[:api_url],
        api_key: options[:api_key]
      )
    end
  end
end
