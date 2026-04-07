# frozen_string_literal: true

require "yaml"

module Blurt
  class FrontmatterParser
    # Returns [Hash, String] — parsed frontmatter hash and body content.
    # If no frontmatter is present, returns [{}, full_content].
    def self.parse(content)
      return [{}, content] unless content.match?(/\A---\s*\n/)

      parts = content.split(/^---\s*$/, 3)
      if parts.length >= 3
        frontmatter = YAML.safe_load(parts[1]) || {}
        body = parts[2].lstrip
        [frontmatter, body]
      else
        [{}, content]
      end
    rescue Psych::SyntaxError
      [{}, content]
    end
  end
end
