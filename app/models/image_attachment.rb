# frozen_string_literal: true

class ImageAttachment
  MAX_IMAGES = 4

  MIME_TYPES = {
    ".jpg"  => "image/jpeg",
    ".jpeg" => "image/jpeg",
    ".png"  => "image/png",
    ".gif"  => "image/gif",
    ".webp" => "image/webp"
  }.freeze

  VALID_EXTENSIONS = MIME_TYPES.keys.freeze

  attr_reader :file_path, :filename, :alt, :mime_type

  def initialize(file_path:, filename:, alt: "", mime_type:)
    @file_path = file_path
    @filename  = filename
    @alt       = alt
    @mime_type = mime_type
  end

  def self.from_frontmatter(data, post_dir)
    return [] unless data.is_a?(Array)

    if data.length > MAX_IMAGES
      raise ArgumentError, "Too many images (#{data.length}), maximum is #{MAX_IMAGES}"
    end

    data.filter_map do |entry|
      next unless entry.is_a?(Hash) && entry["path"]

      path = entry["path"].to_s
      alt = entry["alt"].to_s
      resolved = File.expand_path(path, post_dir)
      basename = File.basename(path)
      ext = File.extname(basename).downcase

      mime = MIME_TYPES[ext]
      unless mime
        raise ArgumentError,
              "Unsupported image type for \"#{basename}\". Supported: #{VALID_EXTENSIONS.join(', ')}"
      end

      unless File.exist?(resolved)
        raise ArgumentError, "Image file not found: #{resolved}"
      end

      new(file_path: resolved, filename: basename, alt: alt, mime_type: mime)
    end
  end
end
