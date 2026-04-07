# frozen_string_literal: true

require "test_helper"
require "tempfile"

class ConfigCommandTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @config_file = File.join(@tmpdir, "config.yml")
    @original_dir = Blurt::Config::CONFIG_DIR
    @original_file = Blurt::Config::CONFIG_FILE
    Blurt::Config.send(:remove_const, :CONFIG_DIR)
    Blurt::Config.send(:remove_const, :CONFIG_FILE)
    Blurt::Config.const_set(:CONFIG_DIR, @tmpdir)
    Blurt::Config.const_set(:CONFIG_FILE, @config_file)

    @original_env = ENV.to_h.slice("BLURT_API_URL", "BLURT_API_KEY")
    ENV.delete("BLURT_API_URL")
    ENV.delete("BLURT_API_KEY")
  end

  def teardown
    Blurt::Config.send(:remove_const, :CONFIG_DIR)
    Blurt::Config.send(:remove_const, :CONFIG_FILE)
    Blurt::Config.const_set(:CONFIG_DIR, @original_dir)
    Blurt::Config.const_set(:CONFIG_FILE, @original_file)

    ENV.delete("BLURT_API_URL")
    ENV.delete("BLURT_API_KEY")
    @original_env.each { |k, v| ENV[k] = v }
    FileUtils.rm_rf(@tmpdir)
  end

  def test_set_api_url
    output = capture_io { Blurt::ConfigCLI.start(["set", "api_url", "https://my-vps.com"]) }.first

    assert_includes output, "api_url"
    assert_includes output, "https://my-vps.com"

    data = YAML.safe_load_file(@config_file)
    assert_equal "https://my-vps.com", data["api_url"]
  end

  def test_set_api_key_masks_output
    output = capture_io { Blurt::ConfigCLI.start(["set", "api_key", "sk-abcdef123456"]) }.first

    assert_includes output, "sk-a"
    refute_includes output, "sk-abcdef123456"

    data = YAML.safe_load_file(@config_file)
    assert_equal "sk-abcdef123456", data["api_key"]
  end

  def test_set_preserves_existing_keys
    File.write(@config_file, { "api_key" => "existing-key" }.to_yaml)

    capture_io { Blurt::ConfigCLI.start(["set", "api_url", "https://new.com"]) }

    data = YAML.safe_load_file(@config_file)
    assert_equal "https://new.com", data["api_url"]
    assert_equal "existing-key", data["api_key"]
  end

  def test_set_rejects_unknown_key
    err_output = capture_io do
      assert_raises(SystemExit) { Blurt::ConfigCLI.start(["set", "bogus", "value"]) }
    end.last

    assert_includes err_output, "Unknown config key: bogus"
    assert_includes err_output, "Valid keys"
  end

  def test_show_displays_current_config
    File.write(@config_file, { "api_url" => "https://my-vps.com", "api_key" => "sk-abcdef123456" }.to_yaml)

    output = capture_io { Blurt::ConfigCLI.start(["show"]) }.first

    assert_includes output, "Blurt Configuration"
    assert_includes output, "https://my-vps.com"
    assert_includes output, "sk-a"
    refute_includes output, "sk-abcdef123456"
    assert_includes output, "config.yml"
  end

  def test_show_when_no_config_exists
    output = capture_io { Blurt::ConfigCLI.start(["show"]) }.first

    assert_includes output, "http://localhost:3000"
    assert_includes output, "(not set)"
  end

  def test_default_task_is_show
    File.write(@config_file, { "api_url" => "https://test.com" }.to_yaml)

    output = capture_io { Blurt::ConfigCLI.start([]) }.first

    assert_includes output, "Blurt Configuration"
    assert_includes output, "https://test.com"
  end
end
