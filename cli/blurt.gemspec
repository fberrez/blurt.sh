# frozen_string_literal: true

require_relative "lib/blurt/version"

Gem::Specification.new do |spec|
  spec.name          = "blurt"
  spec.version       = Blurt::VERSION
  spec.authors       = [ "Florian Music Berrez" ]
  spec.email         = [ "florian@blurt.sh" ]
  spec.summary       = "CLI for Blurt — own your social publishing"
  spec.description   = "Command-line client for the Blurt social publishing queue. " \
                        "Create posts, manage your queue, and publish to all platforms."
  spec.homepage      = "https://github.com/fberrez/blurt.sh"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.files         = Dir["lib/**/*", "bin/*", "README.md", "LICENSE"]
  spec.bindir        = "bin"
  spec.executables   = [ "blurt" ]
  spec.require_paths = [ "lib" ]

  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "thor", "~> 1.3"

  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "webmock", "~> 3.0"
end
