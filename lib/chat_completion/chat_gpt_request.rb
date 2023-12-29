# frozen_string_literal: true

# ChatGptRequest is a PORO that represents the request to the OpenAI ChatCompletion API.
# #to_json is ultimate the output of this class, needed by the RestGateway
#
# Convenience methods are provided for encapsulating and manipulating the messages stack
class ChatGptRequest

  attr_accessor :model, :function_call, :max_tokens, :messages, :functions

  def initialize
    @model = 'gpt-3.5-turbo-0613'
    @function_call = 'auto'
    @max_tokens = 80
    @messages = []
    @functions = []
  end

  ##### Functions for manipulating ChatGPT message stack #####
  def replace_system_directives(content)
    messages.reject! { |message| message[:role] == 'system' }
    add_system_message(content)
  end

  def append_system_directives(content)
    last_directive = messages.rindex { |message| message[:role] == 'system' }

    if last_directive
      messages[last_directive][:content] += "\n#{content}"
    else
      messages.append({ role: 'system', content: })
    end
  end

  def add_system_message(content, before_last_user: true)
    last_user = messages.rindex { |message| message[:role] == 'user' }
    if before_last_user && last_user
      messages.insert(last_user, { role: 'system', content: })
    else
      add_message('system', content)
    end
  end

  def add_agent_message(content)
    add_message('assistant', content)
  end

  def add_user_message(content)
    add_message('user', content)
  end

  def add_message(role, content)
    messages.append({ role:, content: })
  end

  def initialize_from_config(config)
    self.model = config[:model] if config[:model]
    self.max_tokens = config[:max_tokens] if config[:max_tokens]
    self.functions = config[:functions] if config[:functions]
    self.functions += config[:forward_functions] if config[:forward_functions]
    self.function_call = config[:function_call] if config[:function_call]

    replace_system_directives(config[:system_directives]) if config[:system_directives]
  end

  def to_json
    {
      model:,
      messages:,
      max_tokens:,
    }.merge(functions.present? ? { functions:, function_call: } : {}).to_json
  end
end
