# frozen_string_literal: true

class PostMover
  QUEUE_DIR  = Rails.root.join("queue").to_s.freeze
  SENT_DIR   = Rails.root.join("sent").to_s.freeze
  FAILED_DIR = Rails.root.join("failed").to_s.freeze

  class << self
    # Move a published post to sent/ with permalink enrichment.
    # results: { "bluesky" => { url: "...", published_at: Time }, ... }
    def move_to_sent(post, results, source_path:)
      frontmatter_additions = {
        "publishedAt" => Time.current.utc.iso8601,
        "results" => build_results_hash(results)
      }

      enrich_and_move(post, source_path, SENT_DIR, frontmatter_additions)
    end

    # Move a failed post to failed/ with error + partial success enrichment.
    # results: { "bluesky" => { url: "..." }, "mastodon" => { error: "..." } }
    def move_to_failed(post, results, source_path:)
      successes = results.select { |_, r| r[:url] }
      errors = results.select { |_, r| r[:error] }

      frontmatter_additions = { "failedAt" => Time.current.utc.iso8601 }
      frontmatter_additions["errors"] = errors.transform_values { |r| r[:error] } if errors.any?
      frontmatter_additions["results"] = build_results_hash(successes) if successes.any?

      enrich_and_move(post, source_path, FAILED_DIR, frontmatter_additions)
    end

    private

    def enrich_and_move(post, source_path, dest_dir, frontmatter_additions)
      md_path = resolve_md_path(post, source_path)
      enrich_file(md_path, frontmatter_additions)

      base_name = File.basename(source_path).delete_suffix(".publishing")
      dest_name = "#{timestamp_prefix}_#{base_name}"
      move_entry(source_path, dest_dir, dest_name)
    end

    def build_results_hash(results)
      results.transform_values do |r|
        hash = {}
        hash["url"] = r[:url] if r[:url]
        hash["publishedAt"] = r[:published_at].utc.iso8601 if r[:published_at]
        hash
      end
    end

    # Find the actual markdown file path given the (possibly .publishing-renamed) source.
    def resolve_md_path(post, source_path)
      if File.directory?(source_path)
        # Directory post: substitute the original post_dir with the locked source_path
        post.file_path.sub(post.post_dir, source_path)
      else
        source_path
      end
    end

    # Parse frontmatter, merge new keys, rewrite the file.
    def enrich_file(md_path, additions)
      raw = File.read(md_path)
      loader = FrontMatterParser::Loader::Yaml.new(allowlist_classes: [ Time, Date ])
      parsed = FrontMatterParser::Parser.new(:md, loader: loader).call(raw)

      merged = parsed.front_matter.merge(additions)
      yaml = merged.to_yaml # Already starts with "---\n"
      enriched = "#{yaml}---\n\n#{parsed.content.strip}\n"

      File.write(md_path, enriched)
    end

    # Timestamp prefix: "2026-03-25T14-30-45-123Z"
    def timestamp_prefix
      Time.current.utc.strftime("%Y-%m-%dT%H-%M-%S-%3NZ")
    end

    # Move a file or directory to destination.
    def move_entry(source, dest_dir, dest_name)
      dest = File.join(dest_dir, dest_name)
      FileUtils.mkdir_p(dest_dir)

      if File.directory?(source)
        FileUtils.cp_r(source, dest)
        FileUtils.rm_rf(source)
      else
        FileUtils.cp(source, dest)
        FileUtils.rm(source)
      end

      Rails.logger.info "[blurt] Moved #{File.basename(source)} → #{dest_dir}/#{dest_name}"
      dest
    end
  end
end
