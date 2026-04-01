# frozen_string_literal: true

class Post
  VALID_PLATFORMS = BlurtConfig::PLATFORMS.freeze
  BLOG_PLATFORMS = %w[medium devto substack].freeze

  attr_reader :file_path, :filename, :content, :raw, :title,
              :platforms, :scheduled_at, :images, :post_dir

  def initialize(attributes = {})
    @file_path    = attributes[:file_path]
    @filename     = attributes[:filename]
    @content      = attributes[:content]
    @raw          = attributes[:raw]
    @title        = attributes[:title]
    @platforms    = attributes[:platforms] || []
    @scheduled_at = attributes[:scheduled_at]
    @images       = attributes[:images] || []
    @post_dir     = attributes[:post_dir]
  end

  def self.from_file(path)
    path = Pathname.new(path).expand_path
    raw = path.read

    loader = FrontMatterParser::Loader::Yaml.new(allowlist_classes: [ Time, Date ])
    parsed = FrontMatterParser::Parser.new(:md, loader: loader).call(raw)
    frontmatter = parsed.front_matter
    content = parsed.content.strip

    platforms = parse_platforms(frontmatter["platforms"])
    scheduled_at = parse_scheduled_at(frontmatter["scheduledAt"] || frontmatter["scheduled_at"])
    title = frontmatter["title"]&.to_s
    images_data = frontmatter["images"]
    images = ImageAttachment.from_frontmatter(images_data, path.dirname.to_s)

    validate_blog_title!(platforms, title, path.basename.to_s)

    new(
      file_path: path.to_s,
      filename: path.basename.to_s,
      content: content,
      raw: raw,
      title: title,
      platforms: platforms,
      scheduled_at: scheduled_at,
      images: images,
      post_dir: path.dirname.to_s
    )
  end

  def scheduled?
    scheduled_at.present? && scheduled_at > Time.current
  end

  def blog_platforms
    platforms & BLOG_PLATFORMS
  end

  def social_platforms
    platforms - BLOG_PLATFORMS
  end

  class << self
    private

    def parse_platforms(raw)
      return [] unless raw.is_a?(Array)

      raw.map(&:to_s).select { |p| VALID_PLATFORMS.include?(p) }
    end

    def parse_scheduled_at(raw)
      return nil if raw.nil?

      raw.is_a?(Time) || raw.is_a?(DateTime) ? raw.to_time : Time.parse(raw.to_s)
    rescue ArgumentError
      nil
    end

    def validate_blog_title!(platforms, title, filename)
      blog = platforms & BLOG_PLATFORMS
      return if blog.empty? || title.present?

      raise ArgumentError, "#{filename}: title is required for blog platforms (#{blog.join(', ')})"
    end
  end
end
