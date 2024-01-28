# frozen_string_literal: true

## ChatGptAgent stores the configuration for a single-task agent's behavior and settings
class ChatGptAgent # rubocop:disable Metrics/ClassLength
  attr_accessor \
    :callbacks,
    :forward_functions,
    :function_call,
    :function_procs,
    :functions,
    :max_tokens,
    :model,
    :modules,
    :request,
    :response,
    :system_directives,
    :state_map,
    :temperature

  def initialize(config_path: nil, config: nil, callbacks: {}, ignore_unknown_configs: false)
    raise ArgumentError, 'config_path or config must be provided' unless config_path || config
    raise ArgumentError, 'config_path and config cannot both be provided' if config_path && config

    config = YAML.load_file(config_path) if config_path

    @callbacks = callbacks
    intiailize_defaults
    initialize_from_config(config, ignore_unknown_configs: ignore_unknown_configs)
  end

  def runnable(interpolations: {})
    dup.tap do |runnable|
      runnable.system_directives = apply_interpolations(interpolations)
    end
  end

  def run(messages:, interpolations: {}, gateway: RestGateway.new)
    agent = runnable(interpolations:)
    @request = ChatGptRequest.new(agent:, messages:)
    @response = gateway.call(request)
    process_response(response)
  end

  def implied_functions
    function_names_from_functions + function_names_from_state_map
  end

  def state_function
    return nil unless state_map

    state_map[:function_name].to_sym
  end

  def state_function_argument
    return nil unless state_map

    state_map[:argument_name].to_sym
  end

  def state_function_argument_value(response_params)
    return nil unless state_map

    (
      response_params[state_function_argument] ||
      response_params[state_function_argument.to_s]
    ).to_sym
  end

  def state_function_action_type(response_params)
    return nil unless state_map

    state_map[:values_map][state_function_argument_value(response_params)].first.first
  end

  def state_function_action_value(response_params)
    return nil unless state_map

    state_map[:values_map][state_function_argument_value(response_params)].first.last
  end

  def state_function_action_params(response_params)
    return nil unless state_map

    response_params.reject { |k, _v| k.to_sym == state_function_argument }.transform_keys(&:to_sym)
  end

  private

  def intiailize_defaults
    @model = 'gpt-3.5-turbo-0613'
    @function_call = 'auto'
    @max_tokens = 80
    @modules = []
    @temperature = 0.9
    @functions = nil
    @forward_functions = nil
    @function_procs = {}
  end

  def initialize_from_config(config, ignore_unknown_configs:)
    valid_keys = %i[
      model max_tokens
      functions forward_functions function_call function_procs
      system_directives state_map modules temperature
    ]
    config.keys.map(&:to_sym).each do |key|
      if valid_keys.include?(key)
        send("#{key}=", config[key])
      elsif !ignore_unknown_configs
        raise ArgumentError, "Unknown key #{key} in config"
      end
    end
  end

  def function_names_from_functions
    return [] unless functions

    functions
      .map { |func_def| func_def[:name] }
      .reject { |func_name| func_name == state_function.to_s }
      .map(&:to_sym) || []
  end

  def function_names_from_state_map
    return [] unless state_map

    state_map[:values_map]
      .values
      .filter { |hash_thing| hash_thing.key?(:function) }
      .map(&:values)
      .flatten
  end

  def apply_interpolations(interpolations)
    result = system_directives.dup
    interpolations.each do |key, val|
      result.gsub!("%{#{key}}", val.is_a?(Proc) ? val.call : val.to_s)
    end
    result
  end

  def process_response(response)
    return response.message if response&.message

    raise 'No useful response from agent' unless response&.function_call

    process_function_response(response)
  end

  def process_function_response(response)
    params = response.function_arguments.transform_keys(&:to_sym)
    return function_procs[response.function_name.to_sym].call(**params) if state_function != response.function_name.to_sym

    process_state_function_response(
      state_function_action_type(params),
      state_function_action_value(params),
      state_function_action_params(params)
    )
  end

  def process_state_function_response(action_type:, action_val:, params:)
    return function_procs[action_val].call(**params) if action_type == :function
    return unless callbacks[action_type]

    callbacks[action_type].call(action_val, **params)
  end
end
