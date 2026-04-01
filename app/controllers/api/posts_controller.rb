# frozen_string_literal: true

module Api
  class PostsController < BaseController
    def index
      status = params[:status] || "queue"
      posts = load_posts_by_status(status)
      posts = filter_by_platform(posts, params[:platform]) if params[:platform]
      posts = filter_by_date_range(posts, params[:after], params[:before])

      render json: { posts: posts.map { |p| serialize_post(p, status_for(p)) } }
    end

    def show
      post, status = find_post_across_dirs(params[:id])
      return render_not_found("Post '#{params[:id]}' not found") unless post

      render json: { post: serialize_post(post, status) }
    end

    def create
      filename = generate_filename(params[:filename], params[:title])
      file_path = File.join(QueueScanner::QUEUE_DIR, filename)

      if File.exist?(file_path)
        return render_error("File '#{filename}' already exists in queue", status: :conflict)
      end

      frontmatter = build_frontmatter(params)
      markdown_content = params[:content] || ""
      file_content = "#{frontmatter.to_yaml}---\n\n#{markdown_content.strip}\n"

      FileUtils.mkdir_p(QueueScanner::QUEUE_DIR)
      File.write(file_path, file_content)

      post = Post.from_file(file_path)
      render json: { post: serialize_post(post, "queue") }, status: :created
    rescue ArgumentError => e
      render_error(e.message)
    end

    def update
      file_path = resolve_queue_path(params[:id])
      return render_not_found("Queued post '#{params[:id]}' not found") unless file_path

      post = Post.from_file(file_path)
      frontmatter = rebuild_frontmatter(post, params)
      content = params[:content] || post.content
      file_content = "#{frontmatter.to_yaml}---\n\n#{content.strip}\n"

      File.write(file_path, file_content)

      updated_post = Post.from_file(file_path)
      render json: { post: serialize_post(updated_post, "queue") }
    rescue ArgumentError => e
      render_error(e.message)
    end

    def destroy
      file_path = resolve_queue_path(params[:id])
      return render_not_found("Queued post '#{params[:id]}' not found") unless file_path

      if File.directory?(file_path)
        FileUtils.rm_rf(file_path)
      else
        FileUtils.rm(file_path)
      end

      render json: { message: "Post '#{params[:id]}' deleted" }
    end

    def publish
      file_path = resolve_queue_path(params[:id])
      return render_not_found("Queued post '#{params[:id]}' not found") unless file_path

      post = Post.from_file(file_path)
      locked_path = QueueScanner.lock!(post)
      return render_error("Could not lock post (already being published?)", status: :conflict) unless locked_path

      results = PublishOrchestrator.publish(post, locked_path: locked_path)
      all_succeeded = results.values.none? { |r| r[:error] }

      render json: {
        post: {
          filename: post.filename,
          title: post.title,
          platforms: post.platforms,
          status: all_succeeded ? "sent" : "failed",
          results: results
        }
      }, status: (all_succeeded ? :ok : :unprocessable_entity)
    rescue => e
      render_error("Publish failed: #{e.message}", status: :internal_server_error)
    end

    private

    def load_posts_by_status(status)
      case status
      when "queue"  then scan_directory(QueueScanner::QUEUE_DIR)
      when "sent"   then scan_directory(PostMover::SENT_DIR)
      when "failed" then scan_directory(PostMover::FAILED_DIR)
      when "all"
        scan_directory(QueueScanner::QUEUE_DIR) +
          scan_directory(PostMover::SENT_DIR) +
          scan_directory(PostMover::FAILED_DIR)
      else
        []
      end
    end

    def scan_directory(dir)
      return [] unless Dir.exist?(dir)

      Dir.children(dir)
        .reject { |e| e == ".gitkeep" || e.end_with?(".publishing") }
        .filter_map do |entry|
          path = File.join(dir, entry)
          if File.directory?(path)
            md_path = resolve_md_in_dir(path)
            md_path ? safe_parse(md_path) : nil
          elsif entry.end_with?(".md")
            safe_parse(path)
          end
        end
    end

    def resolve_md_in_dir(dir_path)
      %w[post.md index.md].each do |name|
        path = File.join(dir_path, name)
        return path if File.exist?(path)
      end
      Dir.glob(File.join(dir_path, "*.md")).first
    end

    def safe_parse(path)
      Post.from_file(path)
    rescue ArgumentError, FrontMatterParser::SyntaxError => e
      Rails.logger.warn "[blurt] API: skipping #{File.basename(path)}: #{e.message}"
      nil
    end

    def filter_by_platform(posts, platform)
      posts.select { |p| p.platforms.include?(platform) }
    end

    def filter_by_date_range(posts, after_str, before_str)
      after_time = after_str ? Time.parse(after_str) : nil
      before_time = before_str ? Time.parse(before_str) : nil

      posts.select do |p|
        ts = p.scheduled_at || File.mtime(p.file_path)
        (!after_time || ts >= after_time) && (!before_time || ts <= before_time)
      end
    rescue ArgumentError
      posts
    end

    def find_post_across_dirs(id)
      [
        [ QueueScanner::QUEUE_DIR, "queue" ],
        [ PostMover::SENT_DIR, "sent" ],
        [ PostMover::FAILED_DIR, "failed" ]
      ].each do |dir, status|
        path = resolve_in_dir(dir, id)
        next unless path
        post = safe_parse(path)
        return [ post, status ] if post
      end
      [ nil, nil ]
    end

    def resolve_in_dir(dir, id)
      return nil unless Dir.exist?(dir)
      decoded = CGI.unescape(id)

      # Exact match
      path = File.join(dir, decoded)
      return path if File.exist?(path)

      # For sent/failed: match by suffix (files have timestamp prefix)
      Dir.children(dir).each do |entry|
        return File.join(dir, entry) if entry.end_with?(decoded)
      end
      nil
    end

    def resolve_queue_path(id)
      decoded = CGI.unescape(id)
      path = File.expand_path(decoded, QueueScanner::QUEUE_DIR)
      return nil unless path.start_with?(QueueScanner::QUEUE_DIR + "/")
      File.exist?(path) ? path : nil
    end

    def generate_filename(user_filename, title)
      if user_filename.present?
        name = user_filename.to_s
        name += ".md" unless name.end_with?(".md")
        return name
      end

      base = if title.present?
        title.parameterize
      else
        Time.current.utc.strftime("%Y%m%d%H%M%S")
      end
      "#{base}.md"
    end

    def build_frontmatter(params)
      fm = {}
      fm["title"] = params[:title] if params[:title].present?
      fm["platforms"] = Array(params[:platforms]) if params[:platforms].present?
      fm["scheduledAt"] = params[:scheduled_at] if params[:scheduled_at].present?
      fm
    end

    def rebuild_frontmatter(post, params)
      fm = {}
      fm["title"] = params.key?(:title) ? params[:title] : post.title
      fm["platforms"] = params.key?(:platforms) ? Array(params[:platforms]) : post.platforms
      if params.key?(:scheduled_at)
        fm["scheduledAt"] = params[:scheduled_at]
      elsif post.scheduled_at
        fm["scheduledAt"] = post.scheduled_at.iso8601
      end
      fm.compact
    end

    def serialize_post(post, status)
      {
        id: post.filename,
        filename: post.filename,
        title: post.title,
        platforms: post.platforms,
        content: post.content,
        scheduled_at: post.scheduled_at&.iso8601,
        status: status,
        images: post.images.map { |img| { filename: img.filename, alt: img.alt } }
      }
    end

    def status_for(post)
      path = post.file_path
      if path.start_with?(PostMover::SENT_DIR)
        "sent"
      elsif path.start_with?(PostMover::FAILED_DIR)
        "failed"
      else
        "queue"
      end
    end
  end
end
