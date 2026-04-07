# frozen_string_literal: true

module Blurt
  module Commands
    class Delete
      def initialize(config)
        @config = config
        @client = Client.new(config)
      end

      def run(id:)
        validate_config!
        @client.delete_post(id)
        Output.success("Deleted: #{id}")
      rescue Client::AuthenticationError
        Output.error("Invalid API key.")
        $stderr.puts "  Set BLURT_API_KEY or run: blurt config set api_key YOUR_KEY"
        exit 1
      rescue Client::NotFoundError
        Output.error("Post not found: #{id}")
        $stderr.puts "  Run 'blurt queue' to see available posts."
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
