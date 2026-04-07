# frozen_string_literal: true

module Blurt
  module Commands
    class History
      def initialize(config)
        @config = config
        @client = Client.new(config)
      end

      def run(page: nil, platform: nil)
        validate_config!

        data = @client.history(page: page, platform: platform)
        entries = data["history"]

        if entries.empty?
          puts "No published posts found."
          return
        end

        Formatters::TableFormatter.print_history(entries)

        total = data["total"] || 0
        current_page = data["page"] || 1
        per_page = data["per_page"] || 25
        total_pages = (total.to_f / per_page).ceil
        puts "\n  Page #{current_page} of #{total_pages} (#{total} total)"
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
