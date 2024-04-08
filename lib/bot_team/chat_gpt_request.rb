# frozen_string_literal: true

# ChatGptRequest is a PORO that represents the request to the OpenAI ChatCompletion API.
# #to_json is ultimate the output of this class, needed by the RestGateway
#
# Convenience methods are provided for encapsulating and manipulating the messages stack
class ChatGptRequest
  attr_accessor :model, :function_call, :max_tokens, :messages, :functions, :temperature, :num_choices

  def initialize(agent: nil, messages: [])
    self.messages = messages
    if agent
      initialize_from_agent(agent)
      return
    end

    @max_tokens = BotTeam.configuration.max_tokens
    @model = BotTeam.configuration.model
    @num_choices = BotTeam.configuration.num_choices
    @temperature = BotTeam.configuration.temperature

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
    # Do the simple attribute copy first
    %i[model max_tokens num_choices functions function_call temperature].each do |key|
      send("#{key}=", agent.send(key)) if agent.send(key)
    end
    # Leave functions nil if possible
    self.functions = (functions || []) + agent.forward_functions if agent.forward_functions&.any?

    replace_system_directives(agent.system_directives) if agent.system_directives
  end

  def to_hash(*_args)
    {
      model:,
      messages:,
      max_tokens:,
      n: num_choices,
      temperature:,
    }.merge(functions&.any? ? tools : {})
  end

  def to_json(*_args)
    to_hash.to_json
  end

  private

  def tools
    {
      tools: functions.map do |function|
        { type: 'function', function: }
      end,
      tool_choice:
    }
  end

  def tool_choice
    if function_call.nil?
      functions.any? ? 'auto' : 'none'
    elsif %w[auto none].include?(function_call)
      function_call
    else
      { type: 'function', function: function_call }
    end
  end
end
