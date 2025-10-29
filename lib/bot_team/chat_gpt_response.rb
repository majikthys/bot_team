# frozen_string_literal: true

# A friendly version of Chat Object response https://platform.openai.com/docs/api-reference/chat/object
class ChatGptResponse
  attr_accessor :attributes, :source_id, :created, :object, :model, :system_fingerprint, :usage, :choices

  def initialize(attributes = {})
    @attributes = attributes
    @source_id = attributes[:source_id]
    @created = attributes[:created]
    @object = attributes[:object]
    @model = attributes[:model]
    @system_fingerprint = attributes[:system_fingerprint]
    @usage = attributes[:usage]
    @choices = attributes[:choices]
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
      choices: json["choices"]
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

  def to_hash
    {
      source_id:,
      created:,
      object:,
      model:,
      system_fingerprint:,
      usage:,
      choices:
    }
  end
end
