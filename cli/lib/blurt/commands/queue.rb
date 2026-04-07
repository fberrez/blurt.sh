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
        Output.error("Invalid API key.")
        $stderr.puts "  Set BLURT_API_KEY or run: blurt config set api_key YOUR_KEY"
        exit 1
      rescue Client::ConnectionError => e
        Output.error(e.message)
        $stderr.puts "  Is the Blurt server running at #{@config.api_url}?"
        exit 1
      end

      private

      def validate_config!
        return if @config.valid?

        Output.error("No API key configured.")
        $stderr.puts "  Set BLURT_API_KEY environment variable"
        $stderr.puts "  or run: blurt config set api_key YOUR_KEY"
        exit 1
      end
    end
  end
end
