# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/focus'
require 'vcr'
require 'webmock/minitest'

require_relative '../lib/bot_team'

require 'modules/leaf'
require 'modules/switchboard'
require 'modules/product'

VCR.configure do |config|
  config.cassette_library_dir = 'test/vcr_cassettes'
  config.hook_into :webmock
  config.ignore_localhost = true
  config.allow_http_connections_when_no_cassette = true
  config.default_cassette_options = {
    record: :new_episodes,
    match_requests_on: %i[method uri body]
  }

  # Filter sensitive information
  config.filter_sensitive_data('<OPENAI_API_KEY>') { ENV.fetch('OPENAI_API_KEY', nil) }
end
