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

  it "captures service_tier from response" do
    chat_gpt_request = ChatGptRequest.new
    chat_gpt_request.functions = nil
    chat_gpt_request.add_user_message("please say hello")
    result = subject.call(chat_gpt_request)

    assert_instance_of ChatGptResponse, result
    refute_nil result.service_tier, "service_tier should be present"
  end

  it "captures usage from response" do
    chat_gpt_request = ChatGptRequest.new
    chat_gpt_request.functions = nil
    chat_gpt_request.add_user_message("please say hello")
    result = subject.call(chat_gpt_request)

    assert_instance_of ChatGptResponse, result
    refute_nil result.usage, "usage should be present"
    refute_nil result.usage["prompt_tokens"], "prompt_tokens should be present"
    refute_nil result.usage["completion_tokens"], "completion_tokens should be present"
    refute_nil result.usage["total_tokens"], "total_tokens should be present"
  end

  it "calculates cost from usage" do
    chat_gpt_request = ChatGptRequest.new
    chat_gpt_request.functions = nil
    chat_gpt_request.add_user_message("please say hello")
    result = subject.call(chat_gpt_request)

    assert_instance_of ChatGptResponse, result
    cost = result.cost

    refute_nil cost, "cost should be calculated"
    assert_instance_of Float, cost
    assert_operator cost, :>, 0, "cost should be positive"
  end
end
