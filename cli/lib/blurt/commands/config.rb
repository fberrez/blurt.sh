# frozen_string_literal: true

require "thor"
require "yaml"

module Blurt
  class ConfigCLI < Thor
    desc "set KEY VALUE", "Set a config value (api_url, api_key)"
    def set(key, value)
      valid_keys = %w[api_url api_key]
      unless valid_keys.include?(key)
        Output.error("Unknown config key: #{key}")
        $stderr.puts "  Valid keys: #{valid_keys.join(', ')}"
        exit 1
      end

      existing = load_existing_config
      existing[key] = value
      Config.save(api_url: existing["api_url"], api_key: existing["api_key"])

      display_value = key == "api_key" ? mask(value) : value
      Output.success("#{key} = #{display_value}")
      puts "  Saved to #{Config::CONFIG_FILE}"
    end

    desc "show", "Show current configuration"
    def show
      config = Config.new
      puts "Blurt Configuration\n\n"
      puts "  api_url:  #{config.api_url}"
      puts "  api_key:  #{config.api_key ? mask(config.api_key) : '(not set)'}"
      puts "\n  Config file: #{Config::CONFIG_FILE}"
    end

    default_task :show

    private

    def mask(value)
      return "(not set)" if value.nil? || value.empty?

      if value.length <= 4
        "*" * value.length
      else
        "#{value[0..3]}#{"*" * (value.length - 4)}"
      end
    end

    def load_existing_config
      return {} unless File.exist?(Config::CONFIG_FILE)

      YAML.safe_load_file(Config::CONFIG_FILE) || {}
    rescue Psych::SyntaxError
      {}
    end
  end
end
