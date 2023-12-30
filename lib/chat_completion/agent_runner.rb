# frozen_string_literal: true

require 'yaml'
require_relative 'chat_gpt_agent'

class AgentRunner
  attr_accessor :config_root, :initial_agent_name, :initial_messages
  attr_reader :current_agent_config
  attr_reader :current_agent

  def initialize(config_root:, modules: [], initial_agent_name: nil, initial_messages: nil)
    @config_root = config_root
    @initial_agent_name = initial_agent_name
    @initial_messages = initial_messages
    load_modules(modules)
  end

  def run_team
    run_agent(agent_name: initial_agent_name, messages: initial_messages)
  end

  def run_agent(agent_name:, messages: nil)
    @current_agent = create_agent(agent_name: agent_name, messages: messages)
    response = @current_agent.call

    return response.message if response&.message

    raise "No useful response from agent" unless response&.function_call

    call_function(response) # function can may 'call_agent()' results in 'run_agent()' being executed
  end

  def call_function(response)
    function_name = response.function_call['name']
    params = response.function_arguments

    send(function_name, **params.transform_keys(&:to_sym))
  end

  def create_agent(agent_name:, messages: nil)
    @current_agent_config = YAML.load_file("#{@config_root}#{agent_name}.yml")
    chat_gpt_agent = ChatGptAgent.new
    chat_gpt_agent.chat_gpt_request.messages = messages if messages&.any?
    chat_gpt_agent.chat_gpt_request.initialize_from_config(@current_agent_config)

    chat_gpt_agent
  end

  def load_modules(modules)
    modules.each { |m| extend m }
  end

  # Functions called by modules
  def call_agent(agent:, sentiment: nil, classification_confidence: nil)
    log_action("call_agent with #{agent} #{sentiment} #{classification_confidence}")
    run_agent(agent_name: agent, messages: @current_agent.chat_gpt_request.messages)
  end
  def log_action(message)
    puts  "ACTION -> #{message}"
  end
end