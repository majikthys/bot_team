# frozen_string_literal: true

module Agent
  class Chooser < ChatGptAgent
    attr_accessor :choice_prompt

    attr_reader :options, :result

    def initialize(**args)
      super
      @choice_prompt = "Please choose from the following options:"
      @options = {}
      @result = nil
    end

    def add_option(name, description: nil, method: nil)
      @options[name] = { description:, method: }
    end

    def run(message = nil, **_rest)
      setup_agent_config_from_options
      super
    end

    private

    def classify_request(result:, **_rest)
      @result = result
      options.dig(result, :method)&.call
    end

    def setup_agent_config_from_options
      set_system_directives_from_options
      add_function(required: true, method: method(:classify_request))
      define_parameter(
        'classify_request',
        'result',
        enum: options.keys,
        description: 'Your guess at which option best fits the user input.'
      )
    end

    def set_system_directives_from_options
      @system_directives ||= ""
      @system_directives += <<~CHOISE_DIRECTIVES

        #{choice_prompt}

        #{options.map { |name, option| " - #{name}: #{option[:description]}" }.join("\n")}

        Please provide your classification by calling the function `classify_request` with the option that reflects the correct classification.
      CHOISE_DIRECTIVES
    end
  end
end
