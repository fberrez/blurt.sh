# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
$LOAD_PATH.unshift File.expand_path("../../cli/lib", __dir__)

require "blurt_mcp"
require "minitest/autorun"
require "webmock/minitest"

WebMock.disable_net_connect!
