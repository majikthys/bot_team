# frozen_string_literal: true

require 'yaml'
require_relative 'chat_gpt_agent'

class AgentRunner
  attr_accessor :config_root, :initial_agent_name, :initial_messages
  attr_reader :current_agent_config, :current_agent, :interpolations

  def initialize(config_root:, modules: [], interpolations: [], initial_agent_name: nil, initial_messages: nil)
    @config_root = config_root
    @initial_agent_name = initial_agent_name
    @initial_messages = initial_messages
    @interpolations = interpolations
    load_modules(modules)
  end

  def run_team
    run_agent(agent_name: initial_agent_name, messages: initial_messages)
  end

  def run_agent(agent_name:, messages: nil)
    create_agent(agent_name: agent_name, messages: messages)
    response = @current_agent.call

    return response.message if response&.message

    raise "No useful response from agent" unless response&.function_call

    call_function(response) # function can may 'call_agent()' results in 'run_agent()' being executed
  end

  def call_function(response)
    function_name = response.function_call['name']
    params = response.function_arguments

    if @current_agent_config[:state_map] && @current_agent_config[:state_map][:function_name] == function_name.to_sym
      # handle state_map function_call
      argument_name = @current_agent_config[:state_map][:argument_name].to_s
      lookup_value = params[argument_name].to_sym
      action_type, action_val = @current_agent_config[:state_map][:values_map][lookup_value].first
      case action_type
      when :agent
        # Hmm... what to do with the params? This seems like it needs more thought
        call_agent(agent: action_val, **params.reject{|k,v| k == argument_name}.transform_keys(&:to_sym))
      when :function
        # send function along but with the map argument removed from the params
        send(action_val, **params.reject{|k,v| k == argument_name}.transform_keys(&:to_sym))
      when :ignore
        ignore(reason: action_val, **params.reject{|k,v| k == argument_name}.transform_keys(&:to_sym))
      else
        raise "Unknown action type #{action_type}"
      end
    else
      send(function_name, **params.transform_keys(&:to_sym)) #vanilla function call
    end
  end

  def create_agent(agent_name:, messages: nil)
    @current_agent_config = load_config(agent_name)
    chat_gpt_agent = ChatGptAgent.new
    chat_gpt_agent.chat_gpt_request.messages = messages if messages&.any?
    chat_gpt_agent.chat_gpt_request.initialize_from_config(@current_agent_config)

    @current_agent = chat_gpt_agent
  end

  def load_config(agent_name)
    config = YAML.load_file("#{@config_root}#{agent_name}.yml")
    @interpolations.each do |key, val|
      if val.is_a?(Proc)
        config[:system_directives].gsub!("%{#{key}}", val.call)
      else
        config[:system_directives].gsub!("%{#{key}}", val.to_s)
      end
    end
    config
  end

  def load_modules(modules)
    modules.each { |m| extend m }
  end

  # Functions called by modules
  def call_agent(agent:, sentiment: nil, classification_confidence: nil)
    log_action("call_agent with #{agent} #{sentiment} #{classification_confidence}")
    run_agent(agent_name: agent, messages: @current_agent.chat_gpt_request.messages)
  end

  def ignore(reason:, sentiment: nil, classification_confidence: nil)
    log_action("IGNORE FUNCTION REASON: #{reason} SENTIMENT: #{sentiment} CONFIDENCE: #{classification_confidence}")
    return nil
  end

  def log_action(message)
    puts  "ACTION -> #{message}"
  end
end