# frozen_string_literal: true

module BotTeam
  class Configuration
    attr_accessor \
      :api_key,
      :max_tokens,
      :model,
      :num_choices,
      :retry_rolloff_exponent,
      :retry_longest_wait,
      :request_timeout,
      :temperature

    def initialize
      @api_key = ENV['OPENAI_API_KEY']
      @max_tokens = 80
      @model = 'gpt-3.5-turbo'
      @num_choices = 1
      @retry_rolloff_exponent = 1.5
      @retry_longest_wait = 25
      @request_timeout = 30
      @temperature = 0.9
    end
  end
end
