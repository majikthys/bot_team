# frozen_string_literal: true

require 'test_helper'

describe RestGateway do
  subject { RestGateway.new }

  it 'talks to api' do
    chat_gpt_request = ChatGptRequest.new
    chat_gpt_request.functions=nil
    chat_gpt_request.add_user_message('please say hello')
    result = subject.call(chat_gpt_request)

    assert_equal ChatGptResponse, result.class
    assert result.message.downcase.include?('hello'), "result should include 'hello'"
  end
end
