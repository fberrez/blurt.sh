# frozen_string_literal: true

require "yaml"
require "fileutils"

module Blurt
  class Config
    DEFAULT_API_URL = "http://localhost:3000"
    CONFIG_DIR = File.join(Dir.home, ".config", "blurt")
    CONFIG_FILE = File.join(CONFIG_DIR, "config.yml")

    attr_reader :api_url, :api_key

    def initialize(api_url: nil, api_key: nil)
      file_config = load_config_file
      @api_url = api_url || ENV["BLURT_API_URL"] || file_config["api_url"] || DEFAULT_API_URL
      @api_key = api_key || ENV["BLURT_API_KEY"] || file_config["api_key"]
    end

    def valid?
      !@api_key.nil? && !@api_key.empty?
    end

    def self.save(api_url:, api_key:)
      FileUtils.mkdir_p(CONFIG_DIR)
      data = {}
      data["api_url"] = api_url if api_url
      data["api_key"] = api_key if api_key
      File.write(CONFIG_FILE, data.to_yaml)
      File.chmod(0o600, CONFIG_FILE)
    end

    private

    def load_config_file
      return {} unless File.exist?(CONFIG_FILE)
      YAML.safe_load_file(CONFIG_FILE) || {}
    rescue Psych::SyntaxError
      {}
    end
  end
end
