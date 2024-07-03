# frozen_string_literal: true

require 'logger'

require_relative 'bot_team/agent_runner'
require_relative 'bot_team/chat_gpt_agent'
require_relative 'bot_team/chat_gpt_request'
require_relative 'bot_team/chat_gpt_response'
require_relative 'bot_team/configuration'
require_relative 'bot_team/rest_gateway'

require_relative 'bot_team/agent'

module BotTeam
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def logger
      configuration.logger
    end
  end
end
