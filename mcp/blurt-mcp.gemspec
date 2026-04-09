# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../cli/lib", __dir__)
require "blurt/version"

Gem::Specification.new do |spec|
  spec.name = "blurt-mcp"
  spec.version = Blurt::VERSION
  spec.authors = ["Florian Music Berrez"]
  spec.email = ["florian@blurt.sh"]

  spec.summary = "MCP server for Blurt — publish from AI editors"
  spec.homepage = "https://github.com/fberrez/blurt.sh"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.files = Dir["lib/**/*.rb", "bin/*"]
  spec.bindir = "bin"
  spec.executables = ["blurt-mcp"]

  spec.add_dependency "mcp", "~> 0.11"

  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "webmock", "~> 3.0"
end
