# frozen_string_literal: true

require "yaml"
require_relative "chat_gpt_agent"
class AgentRunner
  attr_accessor :config_root, :initial_agent_name, :initial_messages
  attr_reader :current_agent_config, :interpolations, :functions, :usage_stats

  def initialize(config_root: nil, modules: [], interpolations: {}, initial_agent_name: nil, initial_messages: nil)
    @rest_gateway = RestGateway.new
    @config_root = config_root
    @initial_agent_name = initial_agent_name
    @initial_messages = initial_messages
    @interpolations = interpolations
    @agents = {}
    @usage_stats = {}
    load_modules(modules)
    @logger = BotTeam.logger
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

    accumulate_usage(response)

    return response.message if response&.message

    raise "No useful response from agent" unless response&.function_call

    call_function(response) # function can may 'call_agent()' results in 'run_agent()' being executed
  end

  def call_function(response) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    function_name = response.function_name.to_sym
    params = response.function_arguments.transform_keys(&:to_sym)

    if @current_agent.state_function == function_name
      # handle state_map function_call
      action_val = @current_agent.state_function_action_value(params)
      params_to_send = @current_agent.state_function_action_params(params)
      case @current_agent.state_function_action_type(params)
      when :agent
        # Hmm... what to do with the params? This seems like it needs more thought
        call_agent(agent: action_val, **params_to_send)
      when :function
        # send function along but with the map argument removed from the params
        @current_agent.function_procs[action_val].call(**params_to_send)
      when :ignore
        ignore(reason: action_val, **params_to_send)
      else
        raise "Unknown action type #{action_type} in state_map for agent"
      end
    else
      @current_agent.function_procs[function_name].call(**params)
    end
  end

  def create_request(agent_name:, messages: [])
    @current_agent = agent_config(agent_name).runnable(interpolations:)
    @chat_gpt_request = ChatGptRequest.new(agent: @current_agent, messages:)
  end

  def agent_config(agent_name)
    key = agent_name.to_s
    return @agents[key] if @agents[key]

    path = "#{config_root}#{key}.yml"
    raise "No config found for agent #{key} at #{path}" unless File.exist?(path)

    agent = ChatGptAgent.new(config_path: "#{config_root}#{key}.yml")
    cache_functions(agent)
    @agents[key] = agent
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
    nil
  end

  def log_action(message)
    @logger.debug "ACTION -> #{message}"
  end

  def total_cost
    cost_calculator = ChatGptCost.new
    total = 0.0

    usage_stats.each do |model, tiers|
      tiers.each do |tier, tokens|
        input_cost = cost_calculator.lookup(model:, tier:, token_type: "input") * tokens[:input]
        cached_cost = (cost_calculator.lookup(model:, tier:, token_type: "input_cached") || 0.0) * tokens[:input_cached]
        output_cost = cost_calculator.lookup(model:, tier:, token_type: "output") * tokens[:output]

        total += (input_cost + cached_cost + output_cost) / 1_000_000.0
      end
    end

    total
  end

  private

  def accumulate_usage(response)
    return unless usage_data_available?(response)

    model = response.model
    tier = response.service_tier || "standard"

    ensure_usage_stats_initialized(model, tier)
    tokens = extract_response_tokens(response)
    add_tokens_to_stats(model, tier, tokens)
  end

  def usage_data_available?(response)
    response&.usage && response&.model && response&.service_tier
  end

  def ensure_usage_stats_initialized(model, tier)
    @usage_stats[model] ||= {}
    @usage_stats[model][tier] ||= { input: 0, input_cached: 0, output: 0, total: 0 }
  end

  def extract_response_tokens(response)
    prompt_tokens = response.usage["prompt_tokens"] || 0
    completion_tokens = response.usage["completion_tokens"] || 0
    cached_tokens = response.usage.dig("prompt_tokens_details", "cached_tokens") || 0
    total_tokens = response.usage["total_tokens"] || 0

    {
      input: prompt_tokens - cached_tokens,
      input_cached: cached_tokens,
      output: completion_tokens,
      total: total_tokens
    }
  end

  def add_tokens_to_stats(model, tier, tokens)
    @usage_stats[model][tier][:input] += tokens[:input]
    @usage_stats[model][tier][:input_cached] += tokens[:input_cached]
    @usage_stats[model][tier][:output] += tokens[:output]
    @usage_stats[model][tier][:total] += tokens[:total]
  end
end
