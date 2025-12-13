# frozen_string_literal: true

require "test_helper"

describe RestGateway do
  def setup
    VCR.insert_cassette("rest_gateway")
  end

  def teardown
    VCR.eject_cassette
  end

  subject { RestGateway.new }

  it "talks to api" do
    chat_gpt_request = ChatGptRequest.new
    chat_gpt_request.functions = nil
    chat_gpt_request.add_user_message("please say hello")
    result = subject.call(chat_gpt_request)

    assert_instance_of ChatGptResponse, result
    assert_includes result.message.downcase, "hello", "result should include 'hello'"
  end

  it "uses per-instance api_key and api_url when provided" do
    custom_key = "custom-test-key"
    custom_url = "https://custom.example.com/v1/chat/completions"

    gateway = RestGateway.new(api_key: custom_key, api_url: custom_url)

    _(gateway.api_key).must_equal custom_key
    _(gateway.api_url).must_equal custom_url
  end

  it "falls back to global config when api_key and api_url not provided" do
    gateway = RestGateway.new

    _(gateway.api_key).must_equal BotTeam.configuration.api_key
    _(gateway.api_url).must_equal BotTeam.configuration.api_url
  end
end
