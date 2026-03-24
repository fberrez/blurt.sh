# frozen_string_literal: true

class MarkdownProcessor
  HEADING_REGEX = /^\#{1,6}\s+/m

  class << self
    def to_plaintext(markdown)
      markdown
        .gsub(/!\[([^\]]*)\]\([^)]+\)/, '\1')       # Remove images, keep alt text
        .gsub(/\[([^\]]+)\]\([^)]+\)/, '\1')         # Links → text only
        .gsub(/(\*{1,3}|_{1,3})(.*?)\1/, '\2')       # Bold/italic markers
        .gsub(/~~(.*?)~~/m, '\1')                     # Strikethrough
        .gsub(/`([^`]+)`/, '\1')                      # Inline code
        .gsub(/```[\s\S]*?```/, "")                   # Code blocks
        .gsub(HEADING_REGEX, "")                      # Heading markers
        .gsub(/^>\s+/m, "")                           # Blockquote markers
        .gsub(/^[-*_]{3,}\s*$/m, "")                  # Horizontal rules
        .gsub(/^[\s]*[-*+]\s+/m, "")                  # Unordered list markers
        .gsub(/^[\s]*\d+\.\s+/m, "")                  # Ordered list markers
        .gsub(/\n{3,}/, "\n\n")                       # Collapse multiple newlines
        .strip
    end

    def to_html(markdown)
      renderer = Redcarpet::Render::HTML.new(
        hard_wrap: true,
        link_attributes: { target: "_blank", rel: "noopener" }
      )
      parser = Redcarpet::Markdown.new(
        renderer,
        autolink: true,
        fenced_code_blocks: true,
        strikethrough: true,
        no_intra_emphasis: true,
        tables: true
      )
      parser.render(markdown).strip
    end
  end
end
