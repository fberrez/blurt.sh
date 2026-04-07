# frozen_string_literal: true

module Blurt
  module Commands
    class Publish
      def initialize(config)
        @config = config
        @client = Client.new(config)
      end

      def run(id:)
        validate_config!

        data = @client.publish_post(id)
        post = data["post"]

        puts "Published: #{post['filename']}"
        puts "  Status: #{post['status']}"

        results = post["results"] || {}
        results.each do |platform, result|
          if result["url"]
            puts "  #{platform}: #{result['url']}"
          elsif result["error"]
            puts "  #{platform}: FAILED \u2014 #{result['error']}"
          end
        end
      rescue Client::AuthenticationError
        $stderr.puts "Error: Invalid API key."
        $stderr.puts "Set BLURT_API_KEY or run: blurt config"
        exit 1
      rescue Client::NotFoundError
        $stderr.puts "Error: Post not found: #{id}"
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
