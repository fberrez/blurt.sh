# frozen_string_literal: true

class ScanQueueJob < ApplicationJob
  queue_as :default
  limits_concurrency to: 1, key: "scan_queue", duration: 5.minutes

  def perform
    posts = QueueScanner.pending_posts

    if posts.empty?
      Rails.logger.debug "[blurt] No pending posts in queue"
      return
    end

    Rails.logger.info "[blurt] Found #{posts.length} pending post(s)"

    posts.each do |post|
      locked_path = QueueScanner.lock!(post)

      unless locked_path
        Rails.logger.warn "[blurt] Could not lock #{post.filename} — already being processed"
        next
      end

      PublishPostJob.perform_later(post.file_path, locked_path)
    end
  end
end
