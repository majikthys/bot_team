# frozen_string_literal: true

require "minitest/autorun"
require "minitest/focus"
require "vcr"
require "webmock/minitest"

require_relative "../lib/bot_team"

require "modules/leaf"
require "modules/switchboard"
require "modules/product"

VCR.configure do |config|
  config.cassette_library_dir = "test/vcr_cassettes"
  config.hook_into :webmock
  config.ignore_localhost = true
  config.allow_http_connections_when_no_cassette = true
  config.default_cassette_options = {
    record: :new_episodes,
    match_requests_on: %i[method uri body]
  }

  # Filter sensitive information
  config.filter_sensitive_data("<OPENAI_API_KEY>") { ENV.fetch("OPENAI_API_KEY", nil) }

  # Custom matcher for multipart file uploads (ignores random boundary)
  config.register_request_matcher :uri_and_multipart_files do |request_1, request_2|
    # Match on method and URI
    request_1.method == request_2.method && request_1.uri == request_2.uri &&
      # For multipart requests, just check if both are multipart (ignore boundary)
      if request_1.headers["Content-Type"]&.any? { |ct| ct.include?("multipart/form-data") }
        request_2.headers["Content-Type"]&.any? { |ct| ct.include?("multipart/form-data") }
      else
        # For non-multipart requests, match on body as usual
        request_1.body == request_2.body
      end
  end
end
