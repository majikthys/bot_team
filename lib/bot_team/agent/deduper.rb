# frozen_string_literal: true

class Agent::Deduper < ChatGptAgent
  attr_reader :results

  def initialize(**args)
    # Set default agent configs before calling super so that
    # they can still be overridden by initialization args
    self.max_tokens = 1000
    super
    @results = nil
  end

  def run(message = nil, **args) # rubocop:disable Metrics/MethodLength
    set_system_directives_from_options
    @result =
      if message.nil? || message.is_a?(String)
        super
      else
        super(message.to_json, **args)
      end
    @result = @result.gsub(/^```.*/, '')
    @result = JSON.parse(@result).map do |obj|
      obj['originals'] = obj['originals'].map { |o| o.transform_keys(&:to_sym) }
      obj.transform_keys(&:to_sym)
    end
  end

  private

  def set_system_directives_from_options
    @system_directives ||= ""
    @system_directives += <<~LIST_DIRECTIVES
      You are a duplicate detector. The user will give you a JSON array of objects. There may be duplicates in the array. Your job is to return a JSON array of objects with the duplicates removed. You can consider two objects to be duplicates if they refer to the same thing.

      For example, if two objects both have an address attribute that is not identical, but means the same thing, you can consider them duplicates.

      Your response should be an array of objects that uses the most standard, proper, or error-free version of all the duplicates' attributes. You should add an "originals" attribute that is an array of all the original objects.

      Please ensure that the JSON you return is parsable and that each contained object has every required attribute or this operation will fail.

      I'll repeat this because it's important: THE JSON YOU RETURN MUST PARSE. WHAT YOU RETURN WILL BE PUT DIRECTLY IN A JSON PARSER AND LOTS OF VERY CUTE CHILDREN WILL BE VERY SAD IF IT DOESN'T PARSE
    LIST_DIRECTIVES
  end
end
