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
end
