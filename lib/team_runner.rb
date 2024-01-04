# frozen_string_literal: true

require_relative 'chat_completion/agent_runner'
require_relative 'chat_completion/chat_gpt_request'

# This is the main entry point.
class TeamRunner
  attr_reader :result
  attr_writer :config_root

  ROLES = ChatGptRequest::ROLES

  # @param messages Hash of messages, with role as key and message as value. Role must be one of ROLES
  # eg{system: 'blah', user: 'blah', assistant: 'blah'}
  def initialize(
    agent_name:,
    messages:,
    modules: [],
    interpolations: []
  )
    @agent_name = agent_name
    @messages = ChatGptRequest.request_messages(role_message_map: messages)
    @modules = modules
    @interpolations = interpolations
    @config_root = config_root
  end

  def call
    runner = AgentRunner.new(
      config_root:,
      initial_agent_name: @agent_name,
      initial_messages: @messages,
      modules: @modules,
      interpolations: @interpolations
    )
    @result = runner.run_team

    result
  end

  def config_root
    @config_root ||= ENV['CHAT_COMPLETION_CONFIG_ROOT']
  end
end
