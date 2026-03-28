# frozen_string_literal: true

module Api
  class HistoryController < BaseController
    def index
      logs = PublishLog.sent.order(published_at: :desc)
      logs = logs.for_platform(params[:platform]) if params[:platform]
      logs = logs.after_date(params[:after]) if params[:after]
      logs = logs.before_date(params[:before]) if params[:before]

      page = (params[:page] || 1).to_i
      per_page = (params[:per_page] || 25).to_i.clamp(1, 100)
      total = logs.count
      logs = logs.offset((page - 1) * per_page).limit(per_page)

      render json: {
        history: logs.map { |log| serialize_log(log) },
        page: page,
        per_page: per_page,
        total: total
      }
    end

    def show
      log = PublishLog.find_by(filename: CGI.unescape(params[:id]))

      unless log
        post = find_in_sent(params[:id])
        return render_not_found("History entry '#{params[:id]}' not found") unless post
        return render json: { post: serialize_post_from_file(post) }
      end

      render json: { post: serialize_log(log) }
    end

    private

    def serialize_log(log)
      {
        id: log.filename,
        filename: log.filename,
        title: log.title,
        platforms: log.platforms,
        status: log.status,
        results: log.results,
        errors: log.publish_errors.presence,
        published_at: log.published_at&.iso8601,
        destination_path: log.destination_path
      }.compact
    end

    def find_in_sent(id)
      dir = PostMover::SENT_DIR
      return nil unless Dir.exist?(dir)
      decoded = CGI.unescape(id)

      Dir.children(dir).each do |entry|
        next unless entry.end_with?(decoded) || entry == decoded
        path = File.join(dir, entry)
        md_path = File.directory?(path) ? resolve_md_in_dir(path) : path
        return Post.from_file(md_path) if md_path
      end
      nil
    rescue ArgumentError, FrontMatterParser::SyntaxError
      nil
    end

    def resolve_md_in_dir(dir_path)
      %w[post.md index.md].each do |name|
        p = File.join(dir_path, name)
        return p if File.exist?(p)
      end
      Dir.glob(File.join(dir_path, "*.md")).first
    end

    def serialize_post_from_file(post)
      {
        id: post.filename,
        filename: post.filename,
        title: post.title,
        platforms: post.platforms,
        content: post.content,
        status: "sent"
      }
    end
  end
end
