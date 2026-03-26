# frozen_string_literal: true

module Publishers
  class Base
    class << self
      def publish(post, config:, images: [])
        new(config).call(post, images)
      end
    end

    def initialize(config)
      @config = config
    end

    def call(post, images)
      raise NotImplementedError, "#{self.class}#call must be implemented"
    end

    private

    def build_connection(base_url, headers: {})
      Faraday.new(url: base_url, headers: headers) do |f|
        f.request :multipart
        f.request :json
        f.response :json, content_type: /\bjson$/
        f.response :raise_error
        f.adapter Faraday.default_adapter
      end
    end

    def prepare_text(post)
      MarkdownProcessor.to_plaintext(post.content)
    end

    def platform_name
      self.class.name.demodulize.delete_suffix("Publisher").downcase
    end

    def log(message)
      Rails.logger.info "[blurt] [#{platform_name}] #{message}"
    end
  end
end
