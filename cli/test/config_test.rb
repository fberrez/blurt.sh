# frozen_string_literal: true

require "test_helper"
require "tempfile"

class ConfigTest < Minitest::Test
  def setup
    @original_env = ENV.to_h.slice("BLURT_API_URL", "BLURT_API_KEY")
    ENV.delete("BLURT_API_URL")
    ENV.delete("BLURT_API_KEY")
  end

  def teardown
    ENV.delete("BLURT_API_URL")
    ENV.delete("BLURT_API_KEY")
    @original_env.each { |k, v| ENV[k] = v }
  end

  def test_defaults_to_localhost
    config = Blurt::Config.new
    assert_equal "http://localhost:3000", config.api_url
  end

  def test_reads_api_url_from_env
    ENV["BLURT_API_URL"] = "https://blurt.sh"
    config = Blurt::Config.new
    assert_equal "https://blurt.sh", config.api_url
  end

  def test_reads_api_key_from_env
    ENV["BLURT_API_KEY"] = "test-key-123"
    config = Blurt::Config.new
    assert_equal "test-key-123", config.api_key
  end

  def test_flags_override_env
    ENV["BLURT_API_URL"] = "https://env.example.com"
    ENV["BLURT_API_KEY"] = "env-key"
    config = Blurt::Config.new(api_url: "https://flag.example.com", api_key: "flag-key")
    assert_equal "https://flag.example.com", config.api_url
    assert_equal "flag-key", config.api_key
  end

  def test_valid_returns_true_when_api_key_set
    config = Blurt::Config.new(api_key: "key")
    assert config.valid?
  end

  def test_valid_returns_false_when_api_key_nil
    config = Blurt::Config.new
    refute config.valid?
  end

  def test_valid_returns_false_when_api_key_empty
    config = Blurt::Config.new(api_key: "")
    refute config.valid?
  end

  def test_reads_config_file
    Dir.mktmpdir do |dir|
      config_file = File.join(dir, "config.yml")
      File.write(config_file, { "api_url" => "https://file.example.com", "api_key" => "file-key" }.to_yaml)

      with_config_file(config_file) do
        config = Blurt::Config.new
        assert_equal "https://file.example.com", config.api_url
        assert_equal "file-key", config.api_key
      end
    end
  end

  def test_env_overrides_config_file
    Dir.mktmpdir do |dir|
      config_file = File.join(dir, "config.yml")
      File.write(config_file, { "api_url" => "https://file.example.com" }.to_yaml)

      ENV["BLURT_API_URL"] = "https://env.example.com"
      with_config_file(config_file) do
        config = Blurt::Config.new
        assert_equal "https://env.example.com", config.api_url
      end
    end
  end

  def test_save_creates_config_file
    Dir.mktmpdir do |dir|
      config_file = File.join(dir, "config.yml")

      with_config_constants(dir, config_file) do
        Blurt::Config.save(api_url: "https://saved.example.com", api_key: "saved-key")

        assert File.exist?(config_file)
        data = YAML.safe_load_file(config_file)
        assert_equal "https://saved.example.com", data["api_url"]
        assert_equal "saved-key", data["api_key"]
      end
    end
  end

  def test_save_sets_restrictive_permissions
    Dir.mktmpdir do |dir|
      config_file = File.join(dir, "config.yml")

      with_config_constants(dir, config_file) do
        Blurt::Config.save(api_url: "https://example.com", api_key: "key")

        mode = File.stat(config_file).mode & 0o777
        assert_equal 0o600, mode
      end
    end
  end

  private

  def with_config_file(path)
    original = Blurt::Config::CONFIG_FILE
    Blurt::Config.send(:remove_const, :CONFIG_FILE)
    Blurt::Config.const_set(:CONFIG_FILE, path)
    yield
  ensure
    Blurt::Config.send(:remove_const, :CONFIG_FILE)
    Blurt::Config.const_set(:CONFIG_FILE, original)
  end

  def with_config_constants(dir, file)
    original_dir = Blurt::Config::CONFIG_DIR
    original_file = Blurt::Config::CONFIG_FILE
    Blurt::Config.send(:remove_const, :CONFIG_DIR)
    Blurt::Config.send(:remove_const, :CONFIG_FILE)
    Blurt::Config.const_set(:CONFIG_DIR, dir)
    Blurt::Config.const_set(:CONFIG_FILE, file)
    yield
  ensure
    Blurt::Config.send(:remove_const, :CONFIG_DIR)
    Blurt::Config.send(:remove_const, :CONFIG_FILE)
    Blurt::Config.const_set(:CONFIG_DIR, original_dir)
    Blurt::Config.const_set(:CONFIG_FILE, original_file)
  end
end
