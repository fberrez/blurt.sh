# frozen_string_literal: true

module Api
  class HealthController < BaseController
    skip_before_action :authenticate_api_key!

    def show
      queue_count = count_dir(QueueScanner::QUEUE_DIR)
      sent_count = count_dir(PostMover::SENT_DIR)
      failed_count = count_dir(PostMover::FAILED_DIR)
      solid_queue_ok = check_solid_queue

      render json: {
        status: solid_queue_ok ? "ok" : "degraded",
        queue: { pending: queue_count },
        sent: { total: sent_count },
        failed: { total: failed_count },
        platforms: {
          configured: BlurtConfig.configured_platforms,
          count: BlurtConfig.configured_platforms.length
        },
        solid_queue: { connected: solid_queue_ok },
        poll_interval_ms: BlurtConfig.poll_interval
      }
    end

    private

    def count_dir(dir)
      return 0 unless Dir.exist?(dir)
      Dir.children(dir).reject { |e| e == ".gitkeep" || e.end_with?(".publishing") }.count
    end

    def check_solid_queue
      ActiveRecord::Base.connection.active?
    rescue
      false
    end
  end
end
