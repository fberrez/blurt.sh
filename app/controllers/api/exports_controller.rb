# frozen_string_literal: true

require "zip"

module Api
  class ExportsController < BaseController
    def show
      sent_dir = PostMover::SENT_DIR

      unless Dir.exist?(sent_dir) && Dir.children(sent_dir).reject { |e| e == ".gitkeep" }.any?
        return render_error("No sent posts to export", status: :not_found)
      end

      zip_data = build_zip(sent_dir)
      timestamp = Time.current.utc.strftime("%Y%m%dT%H%M%SZ")

      send_data zip_data.string,
                type: "application/zip",
                disposition: "attachment",
                filename: "blurt-export-#{timestamp}.zip"
    end

    private

    def build_zip(dir)
      buffer = Zip::OutputStream.write_buffer do |zip|
        collect_files(dir).each do |relative_path, full_path|
          zip.put_next_entry(relative_path)
          zip.write(File.read(full_path))
        end
      end
      buffer.rewind
      buffer
    end

    def collect_files(dir)
      files = []
      Dir.glob(File.join(dir, "**", "*")).each do |full_path|
        next if File.directory?(full_path)
        next if File.basename(full_path) == ".gitkeep"
        relative = Pathname.new(full_path).relative_path_from(Pathname.new(dir)).to_s
        files << [ relative, full_path ]
      end
      files
    end
  end
end
