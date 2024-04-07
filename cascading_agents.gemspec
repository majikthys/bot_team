# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = "bot_team"
  s.version     = "0.0.1"
  s.required_ruby_version = '>= 3.1.2'
  s.summary     = "cascading llm agent pattern"
  s.description = ""
  s.authors     = ["Jeremy Franklin-Ross, Mike McCracken"]
  s.email       = "majikthys@gmail.com"
  s.files       = Dir['lib/**/*.rb'] + Dir['[A-Z]*']
  s.homepage    = "https://github.com/majikthys/cascading_agents"
  s.metadata    = { "source_code_uri" => "https://github.com/majikthys/cascading_agents",
                    'rubygems_mfa_required' => 'true' }
  s.license     = "GPL-3.0-or-later"
  s.post_install_message = "Art is anything you can get away with. -- Marshall McLuhan"
end
