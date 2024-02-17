# frozen_string_literal: true

module BotTeam
  class Configuration
    attr_accessor \
      :max_tokens,
      :model,
      :num_choices,
      :temperature

    def initialize
      @max_tokens = 80
      @model = 'gpt-3.5-turbo'
      @num_choices = 1
      @temperature = 0.9
    end
  end
end
