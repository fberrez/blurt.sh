# frozen_string_literal: true

class PublishOrchestrator
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

      results
    end

    private

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

      platforms.zip(futures.map(&:value)).to_h
    end

    def publish_to_platform(platform, post, images)
      publisher = publisher_for(platform)
      config = BlurtConfig.send(platform)
      publisher.publish(post, config: config, images: images)
    rescue => e
      Rails.logger.error "[blurt] #{post.filename} → #{platform}: #{e.class}: #{e.message}"
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
