# frozen_string_literal: true

class ChatGptAgent
  attr_accessor \
    :forward_functions, 
    :function_call, 
    :functions, 
    :max_tokens, 
    :model, 
    :system_directives, 
    :state_map

  def initialize(config_path: nil, config: nil)
    raise ArgumentError, 'config_path or config must be provided' unless config_path || config
    raise ArgumentError, 'config_path and config cannot both be provided' if config_path && config

    config = YAML.load_file(config_path) if config_path
    self.model = config[:model]
    self.max_tokens = config[:max_tokens]
    self.functions = config[:functions]
    self.forward_functions = config[:forward_functions]
    self.function_call = config[:function_call]
    self.system_directives = config[:system_directives]
    self.state_map = config[:state_map]
  end
end
