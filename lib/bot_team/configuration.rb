# frozen_string_literal: true

module BotTeam
  class Configuration
    attr_accessor \
      :api_key,
      :api_url,
      :logger,
      :max_tokens,
      :model,
      :num_choices,
      :retry_rolloff_exponent,
      :retry_longest_wait,
      :request_timeout,
      :temperature

    attr_reader \
      :log_level

    def initialize # rubocop:disable Metrics/MethodLength
      @api_key = ENV.fetch("OPENAI_API_KEY", nil)
      @api_url = "https://api.openai.com/v1/chat/completions"
      @log_level = :info
      @logger = Logger.new($stdout).tap { |l| l.level = @log_level }
      @max_tokens = 80
      @model = "gpt-3.5-turbo"
      @num_choices = 1
      @retry_rolloff_exponent = 1.5
      @retry_longest_wait = 25
      @request_timeout = 30
      @temperature = 0.9
    end

    def log_level=(level)
      @log_level = level
      @logger.level = level
    end
  end
end
