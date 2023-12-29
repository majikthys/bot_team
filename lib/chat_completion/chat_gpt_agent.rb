# frozen_string_literal: true

require_relative 'chat_gpt_request'
require_relative 'rest_gateway'

# ChatGptAgent is concerned with
# 1) coordinating ChatGptRequest, RestGateway
# 2) interpreting ChatGptResponse and calling functions
#
# In order to call functions, ability modules loaded. Such functions, must
# correspond to the functions called out in the ChatGptRequest
#
# TODO: A Factory should be responsible for instantiating ChatGptRequest, RestGateway, and
# perhaps a Logger or call returns a full manifest of response_text, chatgptrequest, and chatgptresponse objects?
class ChatGptAgent

  attr_reader :messages, :functions, :response, :rest_gateway, :chat_gpt_request, :max_tokens, :function_call

  # TODO: Factory Refactor - Why do we have phone_number here only to support response building? Seems like bad encapsulation, perhaps
  # better to have reference to an initial response object
  attr_accessor :phone_number

  def initialize
    @rest_gateway = RestGateway.new
    @chat_gpt_request = ChatGptRequest.new
  end

  # @return nil or string intended to be sent to user
  def call
    @response = rest_gateway.call(@chat_gpt_request)

    if @response.function_call
      call_function
    elsif @response.message
      @response.message
    end
  end

  def load_module(module_name)
    require module_name.downcase #infer file name from module name. TODO: this is clumsy, should revisit
    extend Object.const_get(module_name)

  end

  private

  def call_function
    function_name = @response.function_call['name']
    params = @response.function_arguments

    send(function_name, **params.transform_keys(&:to_sym))
  end

  def log_action(message)
    puts  "ACTION -> #{message}"
  end

  def log(message)
    puts  "LOG -> #{message}"
  end

end
