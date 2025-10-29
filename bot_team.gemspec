# frozen_string_literal: true

lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "bot_team/version"

Gem::Specification.new do |s|
  s.name        = "bot_team"
  s.version     = BotTeam::VERSION
  s.required_ruby_version = ">= 3.1.2"
  s.summary     = "For directed agentic architectures"
  s.description = "Library for creating directed agentic architectures, currently using openai chatgpt."
  s.authors     = [ "Jeremy Franklin-Ross, Mike McCracken" ]
  s.email       = "majikthys@gmail.com"
  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  s.files       = Dir.chdir(File.expand_path("..", __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  # s.files       = Dir['lib/**/*.rb'] + Dir['[A-Z]*']

  s.homepage    = "https://github.com/majikthys/bot_team"
  s.metadata    = { "source_code_uri" => "https://github.com/majikthys/bot_team",
                    "rubygems_mfa_required" => "true" }
  s.license     = "GPL-3.0-or-later"
  s.post_install_message = "Art is anything you can get away with. -- Marshall McLuhan"

  s.require_paths = [ "lib" ]

  s.add_development_dependency "bundler", "~> 2.3.26"
  s.add_development_dependency "guard", "~> 2.18.1"
  s.add_development_dependency "guard-minitest", "~> 2.4.6"
  s.add_development_dependency "guard-rubocop", "~> 1.5.0"
  s.add_development_dependency "minitest", "~> 5.0"
  s.add_development_dependency "minitest-focus", "~> 1.4.0"
  s.add_development_dependency "pry-byebug", "~> 3.10.1"
  s.add_development_dependency "rake", "~> 10.0"
  s.add_development_dependency "rubocop", "~> 1.62.1"
  s.add_development_dependency "rubocop-minitest", "~> 0.35.0"
  s.add_development_dependency "ruby-lsp", "~> 0.13.4"
  s.add_development_dependency "vcr", "~> 6.2.0"
  s.add_development_dependency "webmock", "~> 3.20.0"

  s.add_dependency "httparty", "~> 0.21.0"
  s.add_dependency "logger", "~> 1.5.0"
end
