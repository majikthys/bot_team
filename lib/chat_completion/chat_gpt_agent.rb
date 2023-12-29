# frozen_string_literal: true

# ChatGptAgent is concerned with
# 1) coordinating ChatGptRequest, RestGateway
# 2) interpreting ChatGptResponse and calling functions
#
# In order to call functions, ability modules loaded. Such functions, must
# correspond to the functions called out in the ChatGptRequest
#
# TODO: A Factory should be responsible for instantiating ChatGptRequest, RestGateway, and
# perhaps a Logger or call returns a full manifest of response_text, chatgptrequest, and chatgptresponse objects?
class ChatCompletion::ChatGptAgent

  attr_reader :messages, :functions, :response, :rest_gateway, :chat_gpt_request, :max_tokens, :function_call

  # TODO: Factory Refactor - Why do we have phone_number here only to support response building? Seems like bad encapsulation, perhaps
  # better to have reference to an initial response object
  attr_accessor :phone_number

  def initialize
    @rest_gateway = ChatCompletion::RestGateway.new
    @chat_gpt_request = ChatCompletion::ChatGptRequest.new
  end

  # @return nil or string intended to be sent to user
  def call
    @response = rest_gateway.call(@chat_gpt_request)

    if @response.function_call.present?
      call_function
    elsif @response.message.present?
      @response.message
    end
  end

  def load_module(module_name)
    extend module_name.constantize

    return unless module_name.ends_with?('Info')

    # TODO: Factory refactor- info modules pertain only to the request object and
    # so the follow section should be moved to ChatGptRequest and Factory, as well the info modules will need refactoring
    # Adds specific info
    methods = module_name.constantize.instance_methods(false).select do |method_name|
      method_name.to_s.ends_with?('_info') && method_name.to_s.starts_with?('add_')
    end
    methods.each do |method_name|
      send(method_name)
    end
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
