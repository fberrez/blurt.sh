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
        Output.success("Post created: #{post['filename']}")
        puts "  Platforms: #{Array(post['platforms']).join(', ')}"
        puts "  Status:    #{post['status']}"
        puts "  Scheduled: #{post['scheduled_at']}" if post["scheduled_at"]
      rescue Client::AuthenticationError
        Output.error("Invalid API key.")
        $stderr.puts "  Set BLURT_API_KEY or run: blurt config set api_key YOUR_KEY"
        exit 1
      rescue Client::ConnectionError => e
        Output.error(e.message)
        $stderr.puts "  Is the Blurt server running at #{@config.api_url}?"
        exit 1
      end

      private

      def validate_config!
        return if @config.valid?

        Output.error("No API key configured.")
        $stderr.puts "  Set BLURT_API_KEY environment variable"
        $stderr.puts "  or run: blurt config set api_key YOUR_KEY"
        exit 1
      end

      def resolve_content(content, file)
        if file
          unless File.exist?(file)
            Output.error("File not found: #{file}")
            exit 1
          end
          raw = File.read(file)
          frontmatter, body = FrontmatterParser.parse(raw)
          [body, frontmatter]
        elsif content
          [content, {}]
        else
          Output.error("Provide content as an argument or use --file.")
          exit 1
        end
      end

      def resolve_platforms(cli_platforms, file_meta)
        if cli_platforms && !cli_platforms.empty?
          cli_platforms
        elsif file_meta["platforms"]
          Array(file_meta["platforms"])
        else
          Output.error("No platforms specified. Use --platforms or add platforms to frontmatter.")
          exit 1
        end
      end

      def validate_input!(content, platforms)
        if content.nil? || content.strip.empty?
          Output.error("Post content cannot be empty.")
          exit 1
        end
      end
    end
  end
end
