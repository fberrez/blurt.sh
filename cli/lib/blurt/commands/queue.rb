# frozen_string_literal: true

module Blurt
  module Commands
    class Queue
      def initialize(config)
        @config = config
        @client = Client.new(config)
      end

      def run(status: "queue", platform: nil)
        validate_config!
        data = @client.list_posts(status: status, platform: platform)
        posts = data["posts"]

        if posts.empty?
          puts "No #{status} posts found."
          return
        end

        Formatters::TableFormatter.print_posts(posts)
      rescue Client::AuthenticationError
        $stderr.puts "Error: Invalid API key."
        $stderr.puts "Set BLURT_API_KEY or run: blurt config"
        exit 1
      rescue Client::ConnectionError => e
        $stderr.puts "Error: #{e.message}"
        exit 1
      end

      private

      def validate_config!
        return if @config.valid?

        $stderr.puts "Error: No API key configured."
        $stderr.puts "Set BLURT_API_KEY environment variable or run: blurt config"
        exit 1
      end
    end
  end
end
