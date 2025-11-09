# frozen_string_literal: true

# A friendly version of Chat Object response https://platform.openai.com/docs/api-reference/chat/object
class ChatGptResponse
  attr_accessor :attributes, :source_id, :created, :object, :model, :system_fingerprint, :usage, :choices, :service_tier

  def initialize(attributes = {})
    @attributes = attributes
    @source_id = attributes[:source_id]
    @created = attributes[:created]
    @object = attributes[:object]
    @model = attributes[:model]
    @system_fingerprint = attributes[:system_fingerprint]
    @usage = attributes[:usage]
    @choices = attributes[:choices]
    @service_tier = attributes[:service_tier]
    @logger = BotTeam.logger
  end

  def self.create_from_json(json)
    new(
      source_id: json["id"],
      created: json["created"],
      object: json["object"],
      model: json["model"],
      system_fingerprint: json["system_fingerprint"],
      usage: json["usage"],
      choices: json["choices"],
      service_tier: json["service_tier"]
    )
  end

  def function_calls
    choices
      .map { |choice| choice.dig("message", "tool_calls") }
      .flatten
      .map { |tool_call| tool_call["function"] }
      .map do |f_call|
        Struct.new(:name, :arguments).new(
          f_call["name"],
          JSON.parse(f_call["arguments"], symbolize_names: true)
        )
      end
  end

  def function_call
    choices[0]&.dig("message", "tool_calls", 0, "function")
  end

  def multiple_function_calls
    choices
      .map { |choice| choice["message"]["tool_calls"] }
      .map { |tool_calls| tool_calls.map { |tool_call| tool_call["function"] } }
      .flatten
  end

  def function_name
    function_call["name"]
  end

  def multiple_function_names
    multiple_function_calls.map { |function_call| function_call["name"] }
  end

  def function_arguments
    parse_function_arguments(function_call["arguments"])
  end

  # Why does this function exist?
  # That 'compact' could get the size out of sync with the multiple_function_names
  def multiple_function_arguments
    multiple_function_calls.map do |function_call|
      parse_function_arguments(function_call["arguments"])
    end.compact
  end

  def parse_function_arguments(arguments)
    JSON.parse(arguments)
  rescue JSON::ParserError => e
    @logger.error "Error parsing JSON function arguments: #{e.message}"
    nil
  end

  def message
    choices[0]&.dig("message", "content")
  end

  def cost
    return nil unless cost_data_available?

    tokens = extract_token_counts
    prices = lookup_prices

    calculate_total_cost(tokens, prices)
  end

  def to_hash
    {
      source_id:,
      created:,
      object:,
      model:,
      system_fingerprint:,
      usage:,
      choices:,
      service_tier:
    }
  end

  private

  def cost_data_available?
    usage && model && service_tier
  end

  def extract_token_counts
    {
      prompt: usage["prompt_tokens"] || 0,
      completion: usage["completion_tokens"] || 0,
      cached: usage.dig("prompt_tokens_details", "cached_tokens") || 0
    }
  end

  def lookup_prices
    cost_calculator = ChatGptCost.new
    tier = service_tier || "default"

    {
      input: cost_calculator.lookup(model:, tier:, token_type: "input"),
      cached: cost_calculator.lookup(model:, tier:, token_type: "input_cached") || 0.0,
      output: cost_calculator.lookup(model:, tier:, token_type: "output")
    }
  end

  def calculate_total_cost(tokens, prices)
    uncached = tokens[:prompt] - tokens[:cached]
    total = (uncached * prices[:input]) +
            (tokens[:cached] * prices[:cached]) +
            (tokens[:completion] * prices[:output])
    total / 1_000_000.0
  end
end
