# frozen_string_literal: true

class PublishOrchestrator
  # Raised when publishing succeeded but post-publish steps failed.
  # This signals to the job that the file must NOT be unlocked back to queue
  # (since that would cause duplicate posts on the next scan).
  class PostPublishedError < StandardError; end

  class << self
    # Publish a post to all its configured platforms in parallel.
    # locked_path is the actual filesystem location (with .publishing suffix).
    def publish(post, locked_path:)
      platforms = publishable_platforms(post)

      if platforms.empty?
        Rails.logger.warn "[blurt] #{post.filename}: no publishable platforms, unlocking"
        QueueScanner.unlock!(locked_path, post.file_path)
        return {}
      end

      processed_images = process_images(post)

      Rails.logger.info "[blurt] Publishing #{post.filename} to #{platforms.join(', ')}"

      results = publish_in_parallel(platforms, post, processed_images)

      move_and_log(post, results, locked_path)

      results
    end

    private

    # Wrap post-publish steps so that failures after publishing raise
    # PostPublishedError instead of a generic error. This prevents the
    # job from unlocking the file back to queue and causing re-publishes.
    def move_and_log(post, results, locked_path)
      all_succeeded = results.values.none? { |r| r[:error] }

      if all_succeeded
        dest = PostMover.move_to_sent(post, results, source_path: locked_path)
        log_results(post, results, :sent)
        record_publish_log(post, results, :sent, dest)
      else
        dest = PostMover.move_to_failed(post, results, source_path: locked_path)
        log_results(post, results, :failed)
        record_publish_log(post, results, :failed, dest)
      end
    rescue => e
      raise PostPublishedError, "Published but failed to move: #{e.class}: #{e.message}"
    end

    def publishable_platforms(post)
      post.platforms & BlurtConfig.configured_platforms
    end

    def process_images(post)
      return [] if post.images.empty?

      post.images.map do |attachment|
        ImageProcessor.read_and_resize(attachment)
      end
    end

    def publish_in_parallel(platforms, post, images)
      futures = platforms.map do |platform|
        Concurrent::Future.execute do
          publish_to_platform(platform, post, images)
        end
      end

      # 30s timeout per future — safety net above Faraday's 15s timeout
      platforms.zip(futures.map { |f| f.value(30) }).to_h.transform_values do |result|
        result || { error: "Publish timed out after 30s" }
      end
    end

    def publish_to_platform(platform, post, images)
      publisher = publisher_for(platform)
      config = BlurtConfig.send(platform)
      publisher.publish(post, config: config, images: images)
    rescue Faraday::TimeoutError => e
      Rails.logger.error "[blurt] #{post.filename} -> #{platform}: timed out -- #{e.message}"
      { error: "#{platform} API timed out -- retry later" }
    rescue Faraday::ConnectionFailed => e
      Rails.logger.error "[blurt] #{post.filename} -> #{platform}: connection failed -- #{e.message}"
      { error: "Could not connect to #{platform} API -- check network" }
    rescue Faraday::UnauthorizedError => e
      Rails.logger.error "[blurt] #{post.filename} -> #{platform}: unauthorized (401) -- #{e.message}"
      { error: "#{platform} authentication failed (401) -- check credentials" }
    rescue Faraday::ClientError => e
      status = e.response&.dig(:status)
      if status == 429
        retry_after = e.response&.dig(:headers, "retry-after")
        msg = "#{platform} rate limited (429)"
        msg += ", retry after #{retry_after}s" if retry_after
        Rails.logger.warn "[blurt] #{post.filename} -> #{platform}: #{msg}"
        { error: msg }
      else
        Rails.logger.error "[blurt] #{post.filename} -> #{platform}: #{e.class} (#{status}): #{e.message}"
        { error: "#{platform} API error (#{status}): #{e.message}" }
      end
    rescue => e
      Rails.logger.error "[blurt] #{post.filename} -> #{platform}: #{e.class}: #{e.message}"
      { error: "#{e.class}: #{e.message}" }
    end

    def publisher_for(platform)
      "Publishers::#{platform.camelize}Publisher".constantize
    end

    def record_publish_log(post, results, status, destination_path)
      PublishLog.record!(post: post, results: results, status: status, destination_path: destination_path)
    rescue => e
      Rails.logger.error "[blurt] PublishLog write failed: #{e.message}"
    end

    def log_results(post, results, destination)
      results.each do |platform, result|
        if result[:url]
          Rails.logger.info "[blurt] #{post.filename} → #{platform}: #{result[:url]}"
        elsif result[:error]
          Rails.logger.error "[blurt] #{post.filename} → #{platform}: FAILED — #{result[:error]}"
        end
      end

      Rails.logger.info "[blurt] #{post.filename} → #{destination}/"
    end
  end
end
