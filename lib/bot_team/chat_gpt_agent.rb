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
    :num_choices,
    :request,
    :response,
    :system_directives,
    :state_map,
    :temperature

  CONFIG_KEYS = %i[
    forward_functions
    function_call
    function_procs
    functions
    num_choices
    max_tokens
    model
    modules
    state_map
    system_directives
    temperature
  ].freeze

  def initialize(**args)
    config_path = args.delete(:config_path)
    callbacks = args.delete(:callbacks) || {}
    ignore_unknown_configs = args.delete(:ignore_unknown_configs)

    config = config_path ? YAML.load_file(config_path) : {}

    @callbacks = callbacks
    intiailize_defaults
    initialize_from_config(config.merge(args), ignore_unknown_configs:) if config
    @logger = BotTeam.logger
  end

  def runnable(interpolations: {})
    dup.tap do |runnable|
      runnable.system_directives = apply_interpolations(interpolations)
    end
  end

  # Supply message (String) to send a single user message
  # Use messages (Array of Hashes) to send a history
  def run(message = nil, messages: nil, interpolations: {}, gateway: RestGateway.new)
    messages = setup_messages_for_run(message, messages)
    agent = runnable(interpolations:)
    @request = ChatGptRequest.new(agent:, messages:)
    @response = gateway.call(request)
    process_response(response)
  end

  def implied_functions
    function_names_from_functions + function_names_from_state_map
  end

  def add_function(name = nil, description: nil, required: false, method: nil, &block)
    proc = pick_proc(method, block)
    function = build_and_add_function(name:, description:, proc:)
    name = function[:name].to_sym
    @function_procs[name] = proc if proc
    set_function_call(name) if required
    build_parameters_from_proc(function, proc)

    function
  end

  # This method can be used to define parameters for tools functions
  # when the function wasn't initialized with a block or method. Or if
  # it was, this allows you to set type, description, and enum
  def define_parameter(function, name, type: nil, description: nil, required: false, enum: nil) # rubocop:disable Metrics/ParameterLists,Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
    function = functions.find { |func| func[:name] == function }
    raise ArgumentError, "No function defined with name #{name}" unless function

    params = function[:parameters] ||= default_parameters

    params[:required] << name.to_s if required
    params[:required].uniq!
    prop = params[:properties][name.to_sym] ||= {}
    prop[:type] = type if type
    prop[:description] = description if description
    prop[:enum] = enum if enum
    prop
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

  #### Initialization and Configuration ####
  def intiailize_defaults # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
    @model ||= BotTeam.configuration.model
    @max_tokens ||= BotTeam.configuration.max_tokens
    @modules ||= []
    @num_choices ||= BotTeam.configuration.num_choices
    @temperature ||= BotTeam.configuration.temperature

    @forward_functions ||= nil
    @functions ||= nil
    @function_call ||= 'auto'
    @function_procs ||= {}
    nil
  end

  def initialize_from_config(config, ignore_unknown_configs:)
    config.keys.map(&:to_sym).each do |key|
      if CONFIG_KEYS.include?(key)
        send("#{key}=", config[key])
      elsif !ignore_unknown_configs
        raise ArgumentError, "Unknown key #{key} in config"
      end
    end
  end

  #### Function and Parameter Definition ####
  def pick_proc(method, block)
    raise ArgumentError, 'Can only provide one of either a method or a block' if method && block

    method || block
  end

  def build_and_add_function(name: nil, description: nil, proc: nil)
    name = proc.name if name.nil? && proc && proc.respond_to?(:name)
    raise ArgumentError, "No name provided for function" unless name

    function = { name: name.to_s }
    function[:description] = description if description
    @functions ||= []
    @functions << function

    function
  end

  def set_function_call(name) # rubocop:disable Naming/AccessorMethodName
    msg = "Cannot set required function when function_call is already defined (current value: #{function_call})"
    raise ArgumentError, msg unless function_call == 'auto'

    @function_call = { name: name.to_s }
  end

  def build_parameters_from_proc(function, proc) # rubocop:disable Metrics/MethodLength
    return unless proc

    proc.parameters.each do |param|
      case param[0]
      when :keyreq
        create_parameter(function, param[1], required: true)
      when :key
        create_parameter(function, param[1])
      when :keyrest
        # do nothing
      when :req, :opt, :rest, :block
        raise ArgumentError,
              "Positional arguments, splats, and blocks are not allowed in tool function, " \
              "use keyword args and double splat only"
      end
    end
  end

  def create_parameter(function, name, required: false)
    params = function[:parameters] ||= default_parameters

    params[:required] << name.to_s if required
    params[:properties][name.to_sym] = { type: 'string' }
  end

  def default_parameters
    { type: 'object', properties: {}, required: [] }
  end

  def function_names_from_functions
    return [] unless functions

    functions
      .map { |func_def| func_def[:name] }
      .reject { |func_name| func_name == state_function.to_s }
      .map(&:to_sym) || []
  end

  def setup_messages_for_run(message, messages)
    raise "run must be supplied with either message or messages" unless message || messages

    messages ||= []
    messages << { role: 'user', content: message } if message
    messages
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

  def process_function_response(response) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    args = response.function_arguments
    if args.nil?
      @logger.error "Warning: got no arguments for function #{response.function_call} - " \
                    "JSON may have failed to parse – skipping"
      return
    end

    params = args.transform_keys(&:to_sym)

    if state_function == response.function_name.to_sym
      return process_state_function_response(params:)
    end

    response.function_calls.map do |function_call|
      function_procs[function_call.name.to_sym].call(**function_call.arguments)
    end
  end

  def process_state_function_response(params:)
    action_type = state_function_action_type(params)
    action_val = state_function_action_value(params)
    action_params = state_function_action_params(params)
    return function_procs[action_val].call(**action_params) if action_type == :function
    return unless callbacks[action_type]

    callbacks[action_type].call(action_val, **action_params)
  end
end
