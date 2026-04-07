# frozen_string_literal: true

module Blurt
  module Commands
    class Status
      def initialize(config)
        @config = config
        @client = Client.new(config)
      end

      def run
        data = @client.health

        status = data["status"]
        queue_count = data.dig("queue", "pending") || 0
        sent_count = data.dig("sent", "total") || 0
        failed_count = data.dig("failed", "total") || 0
        platforms = data.dig("platforms", "configured") || []
        platform_count = data.dig("platforms", "count") || 0
        worker_ok = data.dig("solid_queue", "connected")
        poll_ms = data["poll_interval_ms"] || 60_000

        status_color = status == "ok" ? :green : :red
        worker_indicator = worker_ok ? Output.checkmark : Output.cross
        worker_label = worker_ok ? "connected" : "disconnected"

        puts "Blurt Status\n\n"
        puts "  Server:     #{@config.api_url} (#{Output.colorize(status, status_color)})"
        puts "  Queue:      #{queue_count} pending"
        puts "  Sent:       #{sent_count} total"
        puts "  Failed:     #{failed_count} total"
        puts "  Platforms:  #{platforms.join(', ')} (#{platform_count}/6 configured)"
        puts "  Worker:     #{worker_indicator} #{worker_label} (polling every #{poll_ms / 1000}s)"
      rescue Client::ConnectionError => e
        Output.error(e.message)
        $stderr.puts "  Is the Blurt server running at #{@config.api_url}?"
        exit 1
      end
    end
  end
end
