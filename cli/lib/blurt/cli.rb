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

    desc "version", "Print blurt version"
    def version
      puts "blurt #{Blurt::VERSION}"
    end

    map %w[-v --version] => :version

    private

    def build_config
      Config.new(
        api_url: options[:api_url],
        api_key: options[:api_key]
      )
    end
  end
end
