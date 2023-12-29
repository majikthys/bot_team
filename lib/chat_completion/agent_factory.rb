# frozen_string_literal: true

require 'yaml'
require_relative 'chat_gpt_agent'

class AgentFactory
  attr_accessor :config_root

  def initialize(config_root)
    # TODO: should be ENV['CHAT_GPT_AGENT_CONFIG_ROOT'] or accommodate db
    @config_root = config_root
  end

  def create_agent(agent_name:)
    config = YAML.load_file("#{@config_root}#{agent_name}.yml")
    chat_gpt_agent = ChatGptAgent.new
    chat_gpt_agent.chat_gpt_request.initialize_from_config(config)

    # load modules (adds abilities/functions and info on directives)
    config[:modules]&.each { |module_name| chat_gpt_agent.load_module(module_name) }

    chat_gpt_agent
  end
end