# frozen_string_literal: true

require_relative 'chat_gpt_request'
require_relative 'rest_gateway'

# ChatGptAgent is concerned with
# 1) coordinating ChatGptRequest, RestGateway
# 2) returning ChatGptResponse
class ChatGptAgent

  attr_reader :messages, :functions, :response, :rest_gateway, :chat_gpt_request, :max_tokens, :function_call

  def initialize(chat_gpt_request: nil, rest_gateway: nil)
    @rest_gateway = rest_gateway || RestGateway.new
    @chat_gpt_request = chat_gpt_request || ChatGptRequest.new
  end

  def call
    @response = rest_gateway.call(@chat_gpt_request)
  end
end
