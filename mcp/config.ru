# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("lib", __dir__)
$LOAD_PATH.unshift File.expand_path("../cli/lib", __dir__)

require "blurt_mcp"
require "blurt_mcp/http_app"

config = Blurt::Config.new(
  api_url: ENV["BLURT_API_URL"],
  api_key: ENV["BLURT_API_KEY"]
)

run BlurtMcp::HttpApp.new(config: config, stateless: true)
