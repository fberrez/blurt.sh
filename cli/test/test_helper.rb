# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "blurt"
require "minitest/autorun"
require "webmock/minitest"

WebMock.disable_net_connect!
