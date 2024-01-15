# frozen_string_literal: true

require 'yaml'
require_relative 'chat_gpt_agent'
class AgentRunner
  attr_accessor :config_root, :initial_agent_name, :initial_messages
  attr_reader :current_agent_config, :interpolations, :functions

  def initialize(config_root: nil, modules: [], interpolations: {}, initial_agent_name: nil, initial_messages: nil)
    @rest_gateway = RestGateway.new
    @config_root = config_root
    @initial_agent_name = initial_agent_name
    @initial_messages = initial_messages
    @interpolations = interpolations
    @agents = {}
    load_modules(modules)
  end

  def add_agent(agent_name, agent)
    @agents[agent_name.to_s] = agent
  end

  def run_team
    run_agent(agent_name: initial_agent_name, messages: initial_messages)
  end

  def run_agent(agent_name:, messages: nil)
    create_request(agent_name:, messages:)
    response = @rest_gateway.call(@chat_gpt_request)

    return response.message if response&.message

    raise "No useful response from agent" unless response&.function_call

    call_function(response) # function can may 'call_agent()' results in 'run_agent()' being executed
  end

  def call_function(response)
    function_name = response.function_call['name'].to_sym
    params = response.function_arguments

    if @current_agent.state_map && @current_agent.state_map[:function_name] == function_name
      # handle state_map function_call
      argument_name = @current_agent.state_map[:argument_name].to_s
      lookup_value = params[argument_name].to_sym
      action_type, action_val = @current_agent.state_map[:values_map][lookup_value].first
      params_to_send = params.reject{|k,v| k == argument_name}.transform_keys(&:to_sym)
      case action_type
      when :agent
        # Hmm... what to do with the params? This seems like it needs more thought
        call_agent(agent: action_val, **params_to_send)
      when :function
        # send function along but with the map argument removed from the params
        @current_agent.function_procs[action_val].call(**params_to_send)
      when :ignore
        ignore(reason: action_val, **params_to_send)
      else
        raise "Unknown action type #{action_type}"
      end
    else
      @current_agent.function_procs[function_name].call(**params.transform_keys(&:to_sym))
    end
  end

  def create_request(agent_name:, messages: [])
    @current_agent = agent(agent_name)
    @chat_gpt_request = ChatGptRequest.new(agent: @current_agent, messages:)
  end

  def agent(agent_name)
    agent = agent_config(agent_name).dup
    agent.system_directives = apply_interpolations(agent.system_directives)
    cache_functions(agent)
    agent
  end

  def agent_config(agent_name)
    key = agent_name.to_s
    return @agents[key] if @agents[key]

    path = "#{config_root}#{key}.yml"
    raise "No config found for agent #{key} at #{path}" unless File.exist?(path)

    @agents[key] = ChatGptAgent.new(config_path: "#{config_root}#{key}.yml")
  end

  def apply_interpolations(system_directives)
    result = system_directives.dup
    @interpolations.each do |key, val|
      result.gsub!("%{#{key}}", val.is_a?(Proc) ? val.call : val.to_s)
    end
    result
  end

  def cache_functions(agent)
    agent
      .implied_functions
      .each do |function_name|
        agent.function_procs[function_name.to_sym] = method(function_name.to_sym)
      end
  end

  def load_modules(modules)
    modules.each { |m| extend m }
  end

  # Functions called by modules
  def call_agent(agent:, sentiment: nil, classification_confidence: nil)
    log_action("call_agent with #{agent} #{sentiment} #{classification_confidence}")
    run_agent(agent_name: agent, messages: @chat_gpt_request.messages)
  end

  def ignore(reason:, sentiment: nil, classification_confidence: nil)
    log_action("IGNORE FUNCTION REASON: #{reason} SENTIMENT: #{sentiment} CONFIDENCE: #{classification_confidence}")
    return nil
  end

  def log_action(message)
    puts  "ACTION -> #{message}" if ENV['DEBUG']
  end
end
