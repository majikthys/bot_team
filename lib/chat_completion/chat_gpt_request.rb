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

  def initialize_from_agent(agent)
    self.model = agent.model if agent.model
    self.max_tokens = agent.max_tokens if agent.max_tokens
    self.functions = agent.functions if agent.functions
    self.functions += agent.forward_functions if agent.forward_functions
    self.function_call = agent.function_call if agent.function_call

    replace_system_directives(agent.system_directives) if agent.system_directives
  end

  def to_json
    {
      model:,
      messages:,
      max_tokens:,
    }.merge(functions != nil ? { functions:, function_call: } : {}).to_json
  end
end
