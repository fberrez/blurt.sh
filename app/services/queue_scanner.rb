# frozen_string_literal: true

class QueueScanner
  QUEUE_DIR = Rails.root.join("queue").to_s.freeze

  @logged_scheduled_mutex = Mutex.new
  @logged_scheduled_posts = Set.new

  class << self
    # Returns array of Post objects ready to publish.
    def pending_posts
      return [] unless Dir.exist?(QUEUE_DIR)

      entries = Dir.children(QUEUE_DIR)
      entries.reject! { |e| e == ".gitkeep" || e.end_with?(".publishing") }

      posts = []

      entries.each do |entry|
        full_path = File.join(QUEUE_DIR, entry)

        post = if File.directory?(full_path)
                 parse_directory_post(full_path)
               elsif entry.end_with?(".md")
                 parse_flat_post(full_path)
               end

        next unless post
        next if skip_scheduled?(post)
        next if publishable_platforms(post).empty?

        posts << post
      end

      cleanup_logged_scheduled(entries)
      posts
    end

    # Lock a post by renaming to .publishing suffix.
    # Returns new path or nil if rename fails (race lost).
    def lock!(post)
      source = lockable_path(post)
      dest = "#{source}.publishing"

      File.rename(source, dest)
      Rails.logger.info "[blurt] Locked #{File.basename(source)}"
      dest
    rescue Errno::ENOENT
      nil
    end

    # Unlock: rename .publishing back to original (error recovery).
    def unlock!(publishing_path, original_path)
      return unless publishing_path && File.exist?(publishing_path)

      original_name = File.basename(original_path)
      dest = File.join(File.dirname(publishing_path), original_name)
      File.rename(publishing_path, dest)
      Rails.logger.info "[blurt] Unlocked #{original_name}"
    rescue Errno::ENOENT
      # Already moved or cleaned up
    end

    private

    def parse_flat_post(path)
      Post.from_file(path)
    rescue ArgumentError, FrontMatterParser::SyntaxError => e
      Rails.logger.warn "[blurt] Skipping #{File.basename(path)}: #{e.message}"
      nil
    end

    def parse_directory_post(dir_path)
      md_path = resolve_directory_entry(dir_path)
      unless md_path
        Rails.logger.warn "[blurt] Skipping directory #{File.basename(dir_path)}: no .md file found"
        return nil
      end

      Post.from_file(md_path)
    rescue ArgumentError, FrontMatterParser::SyntaxError => e
      Rails.logger.warn "[blurt] Skipping #{File.basename(dir_path)}: #{e.message}"
      nil
    end

    # Find the markdown file inside a post directory.
    # Priority: post.md > index.md > first .md found
    def resolve_directory_entry(dir_path)
      %w[post.md index.md].each do |name|
        path = File.join(dir_path, name)
        return path if File.exist?(path)
      end

      Dir.glob(File.join(dir_path, "*.md")).first
    end

    def skip_scheduled?(post)
      return false unless post.scheduled?

      log_scheduled_once(post)
      true
    end

    def publishable_platforms(post)
      configured = BlurtConfig.configured_platforms
      active = post.platforms & configured

      if active.empty?
        Rails.logger.warn "[blurt] Skipping #{post.filename}: no configured platforms " \
                          "(post wants #{post.platforms.join(', ')})"
      end

      active
    end

    # Determine the filesystem entry to rename for locking.
    def lockable_path(post)
      parent = Pathname.new(post.post_dir).parent.to_s
      if parent == QUEUE_DIR
        # Directory post: lock the directory itself
        post.post_dir
      else
        # Flat file: lock the file
        post.file_path
      end
    end

    def log_scheduled_once(post)
      @logged_scheduled_mutex.synchronize do
        key = post.file_path
        unless @logged_scheduled_posts.include?(key)
          @logged_scheduled_posts.add(key)
          Rails.logger.info "[blurt] Skipping scheduled post: #{post.filename} " \
                            "(scheduled for #{post.scheduled_at.iso8601})"
        end
      end
    end

    # Remove entries from the logged set that are no longer in the queue.
    def cleanup_logged_scheduled(current_entries)
      @logged_scheduled_mutex.synchronize do
        @logged_scheduled_posts.select! do |path|
          basename = File.basename(path)
          dir = File.basename(File.dirname(path))
          current_entries.include?(basename) || current_entries.include?(dir)
        end
      end
    end
  end
end
