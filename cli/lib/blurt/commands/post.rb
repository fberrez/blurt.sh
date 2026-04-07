# frozen_string_literal: true

module Blurt
  module Commands
    class Post
      def initialize(config)
        @config = config
        @client = Client.new(config)
      end

      def run(content: nil, file: nil, platforms: nil, title: nil, scheduled_at: nil)
        validate_config!
        content, file_meta = resolve_content(content, file)
        platforms = resolve_platforms(platforms, file_meta)
        title = title || file_meta["title"]
        scheduled_at = scheduled_at || file_meta["scheduled_at"] || file_meta["scheduledAt"]

        validate_input!(content, platforms)

        data = @client.create_post(
          content: content,
          platforms: platforms,
          title: title,
          scheduled_at: scheduled_at
        )

        post = data["post"]
        puts "Post created: #{post['filename']}"
        puts "  Platforms: #{Array(post['platforms']).join(', ')}"
        puts "  Status:    #{post['status']}"
        puts "  Scheduled: #{post['scheduled_at']}" if post["scheduled_at"]
      rescue Client::AuthenticationError
        $stderr.puts "Error: Invalid API key."
        $stderr.puts "Set BLURT_API_KEY or run: blurt config"
        exit 1
      rescue Client::ConnectionError => e
        $stderr.puts "Error: #{e.message}"
        exit 1
      end

      private

      def validate_config!
        return if @config.valid?

        $stderr.puts "Error: No API key configured."
        $stderr.puts "Set BLURT_API_KEY environment variable or run: blurt config"
        exit 1
      end

      def resolve_content(content, file)
        if file
          unless File.exist?(file)
            $stderr.puts "Error: File not found: #{file}"
            exit 1
          end
          raw = File.read(file)
          frontmatter, body = FrontmatterParser.parse(raw)
          [body, frontmatter]
        elsif content
          [content, {}]
        else
          $stderr.puts "Error: Provide content as an argument or use --file."
          exit 1
        end
      end

      def resolve_platforms(cli_platforms, file_meta)
        if cli_platforms && !cli_platforms.empty?
          cli_platforms
        elsif file_meta["platforms"]
          Array(file_meta["platforms"])
        else
          $stderr.puts "Error: No platforms specified. Use --platforms or add platforms to frontmatter."
          exit 1
        end
      end

      def validate_input!(content, platforms)
        if content.nil? || content.strip.empty?
          $stderr.puts "Error: Post content cannot be empty."
          exit 1
        end
      end
    end
  end
end
