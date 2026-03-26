# frozen_string_literal: true

class ImageProcessor
  DEFAULT_MAX_BYTES = 1_000_000 # 1 MB
  MIN_WIDTH = 200
  SHRINK_FACTOR = 0.75
  JPEG_QUALITY = 80
  PNG_COMPRESSION = 9

  FORMAT_MAP = {
    "image/jpeg" => :jpg,
    "image/png"  => :png,
    "image/webp" => :webp,
    "image/gif"  => :gif
  }.freeze

  class << self
    # Reads an image file and resizes if over max_bytes.
    # Returns { io: StringIO, filename: String, mime_type: String, byte_size: Integer }
    def read_and_resize(attachment, max_bytes: DEFAULT_MAX_BYTES)
      file_path = attachment.file_path
      raise ArgumentError, "Image file not found: #{file_path}" unless File.exist?(file_path)

      raw_bytes = File.binread(file_path)

      if raw_bytes.bytesize <= max_bytes || attachment.mime_type == "image/gif"
        if raw_bytes.bytesize > max_bytes && attachment.mime_type == "image/gif"
          Rails.logger.warn "[blurt] GIF #{attachment.filename} is #{format_size(raw_bytes.bytesize)}, " \
                            "skipping resize to preserve animation"
        end

        return {
          io: StringIO.new(raw_bytes),
          filename: attachment.filename,
          alt: attachment.alt,
          mime_type: attachment.mime_type,
          byte_size: raw_bytes.bytesize
        }
      end

      Rails.logger.info "[blurt] #{attachment.filename} is #{format_size(raw_bytes.bytesize)}, " \
                        "resizing to fit #{format_size(max_bytes)} limit"

      resized_path = shrink_to_fit(file_path, attachment.mime_type, max_bytes)
      resized_bytes = File.binread(resized_path)

      Rails.logger.info "[blurt] #{attachment.filename} resized to #{format_size(resized_bytes.bytesize)}"

      {
        io: StringIO.new(resized_bytes),
        filename: attachment.filename,
        alt: attachment.alt,
        mime_type: attachment.mime_type,
        byte_size: resized_bytes.bytesize
      }
    ensure
      File.delete(resized_path) if defined?(resized_path) && resized_path && File.exist?(resized_path)
    end

    # Progressive width reduction until image fits under max_bytes.
    # Returns path to a tempfile with the resized image.
    def shrink_to_fit(file_path, mime_type, max_bytes)
      format = FORMAT_MAP[mime_type] || :jpg
      image = Vips::Image.new_from_file(file_path)
      width = image.width

      loop do
        width = (width * SHRINK_FACTOR).to_i

        if width < MIN_WIDTH
          raise "Cannot shrink #{File.basename(file_path)} below #{MIN_WIDTH}px " \
                "and stay under #{format_size(max_bytes)}"
        end

        result = ImageProcessing::Vips
          .source(file_path)
          .resize_to_limit(width, nil)
          .convert(format.to_s)
          .saver(**saver_options(format))
          .call

        return result.path if File.size(result.path) <= max_bytes
      end
    end

    private

    def saver_options(format)
      case format
      when :jpg, :jpeg then { quality: JPEG_QUALITY }
      when :png then { compression: PNG_COMPRESSION }
      when :webp then { quality: JPEG_QUALITY }
      else {}
      end
    end

    def format_size(bytes)
      "%.2fMB" % (bytes.to_f / 1_000_000)
    end
  end
end
