# frozen_string_literal: true

## ChatGptAgent stores the configuration for a single-task agent's behavior and settings
class ChatGptAgent
  attr_accessor \
    :forward_functions,
    :function_call,
    :functions,
    :max_tokens,
    :model,
    :modules,
    :system_directives,
    :state_map

  def initialize(config_path: nil, config: nil)
    raise ArgumentError, 'config_path or config must be provided' unless config_path || config
    raise ArgumentError, 'config_path and config cannot both be provided' if config_path && config

    config = YAML.load_file(config_path) if config_path

    intiailize_defaults
    initialize_from_config(config)
  end

  def implied_functions
    function_names_from_functions + function_names_from_state_map
  end

  private

  def intiailize_defaults
    @model = 'gpt-3.5-turbo-0613'
    @function_call = 'auto'
    @max_tokens = 80
    @modules = []
    @functions = nil
    @forward_functions = nil
  end

  def initialize_from_config(config)
    valid_keys = %i[
      model max_tokens
      functions forward_functions function_call
      system_directives state_map modules
    ]
    config.keys.map(&:to_sym).each do |key|
      raise ArgumentError, "Unknown key #{key} in config" unless valid_keys.include?(key)

      send("#{key}=", config[key])
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

  def state_function
    return nil unless state_map

    state_map[:function_name]
  end
end
