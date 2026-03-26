# frozen_string_literal: true

class PublishPostJob < ApplicationJob
  queue_as :default
  discard_on Errno::ENOENT

  # original_path: where the file was before locking (for unlock recovery + naming)
  # locked_path: where the file is now (.publishing suffix)
  def perform(original_path, locked_path)
    post = reconstitute_post(locked_path)
    PublishOrchestrator.publish(post, locked_path: locked_path)
  rescue Errno::ENOENT
    raise # Let discard_on handle it
  rescue => e
    Rails.logger.error "[blurt] PublishPostJob failed for #{File.basename(original_path)}: #{e.message}"
    QueueScanner.unlock!(locked_path, original_path) rescue nil
    raise
  end

  private

  def reconstitute_post(locked_path)
    if File.directory?(locked_path)
      md_path = find_md_in_directory(locked_path)
      Post.from_file(md_path)
    else
      Post.from_file(locked_path)
    end
  end

  def find_md_in_directory(dir_path)
    %w[post.md index.md].each do |name|
      path = File.join(dir_path, name)
      return path if File.exist?(path)
    end

    Dir.glob(File.join(dir_path, "*.md")).first ||
      raise(Errno::ENOENT, "No markdown file found in #{dir_path}")
  end
end
