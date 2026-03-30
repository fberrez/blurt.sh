# frozen_string_literal: true

module Blurt
  module Formatters
    class TableFormatter
      def self.print_posts(posts)
        puts "#{posts.length} post(s):\n\n"
        rows = [%w[FILENAME PLATFORMS STATUS SCHEDULED]]
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

      def self.print_table(rows)
        widths = rows.transpose.map { |col| col.map(&:to_s).map(&:length).max }
        rows.each do |row|
          puts "  " + row.zip(widths).map { |val, w| val.to_s.ljust(w) }.join("  ")
        end
      end
    end
  end
end
