# frozen_string_literal: true

module Blurt
  module Formatters
    class TableFormatter
      def self.print_posts(posts)
        puts "#{posts.length} post(s):\n\n"
        rows = [ %w[FILENAME PLATFORMS STATUS SCHEDULED] ]
        posts.each do |post|
          rows << [
            post["filename"],
            Array(post["platforms"]).join(", "),
            post["status"],
            post["scheduled_at"] || "\u2014"
          ]
        end
        print_table(rows)
      end

      def self.print_history(entries)
        puts "#{entries.length} published post(s):\n\n"
        rows = [%w[FILENAME PLATFORMS PUBLISHED URLS]]
        entries.each do |entry|
          results = entry["results"] || {}
          urls = results.map { |_platform, r| r["url"] }.compact
          rows << [
            entry["filename"],
            Array(entry["platforms"]).join(", "),
            entry["published_at"] || "\u2014",
            truncate_urls(urls)
          ]
        end
        print_table(rows)
      end

      def self.print_table(rows)
        widths = rows.transpose.map { |col| col.map(&:to_s).map(&:length).max }
        rows.each_with_index do |row, idx|
          formatted = row.zip(widths).map { |val, w| val.to_s.ljust(w) }.join("  ")
          formatted = Output.colorize(formatted, :bold) if idx.zero?
          puts "  #{formatted}"
        end
      end

      def self.truncate_urls(urls)
        return "\u2014" if urls.empty?

        if urls.length == 1
          urls.first
        else
          "#{urls.first} (+#{urls.length - 1} more)"
        end
      end
    end
  end
end
