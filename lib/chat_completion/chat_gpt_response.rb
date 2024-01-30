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
  end

  def self.create_from_json(json)
    new(
      source_id: json['id'],
      created: json['created'],
      object: json['object'],
      model: json['model'],
      system_fingerprint: json['system_fingerprint'],
      usage: json['usage'],
      choices: json['choices']
    )
  end

  def function_call
    choices[0]&.dig('message', 'function_call')
  end

  def multiple_function_calls
    choices.map { |choice| choice['message']['function_call'] }
  end

  def function_name
    function_call['name']
  end

  def multiple_function_names
    multiple_function_calls.map { |function_call| function_call['name'] }
  end

  def function_arguments
    parse_function_arguments(function_call['arguments'])
  end

  def multiple_function_arguments
    multiple_function_calls.map do |function_call|
      parse_function_arguments(function_call['arguments'])
    end.compact
  end

  def parse_function_arguments(arguments)
    JSON.parse(arguments)
  rescue JSON::ParserError => e
    $stderr.puts "Error parsing JSON: #{e.message}"
    nil
  end

  def message
    choices[0]&.dig('message', 'content')
  end

  def to_hash
    {
      source_id: source_id,
      created: created,
      object: object,
      model: model,
      system_fingerprint: system_fingerprint,
      usage: usage,
      choices: choices
    }
  end
end
