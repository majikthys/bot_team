# frozen_string_literal: true

# A friendly version of Chat Object response https://platform.openai.com/docs/api-reference/chat/object
class ChatGptResponse
  attr_accessor :source_id, :created, :object, :model, :system_fingerprint, :usage, :choices

  def initialize(attributes = {})
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
      system_fingerprint: json['system_fingerprint'] ? Time.utc(json['system_fingerprint']) : nil,
      usage: json['usage'],
      choices: json['choices']
    )
  end

  def function_call
    choices[0]&.dig('message', 'function_call')
  end

  def function_name
    function_call['name']
  end

  def function_arguments
    JSON.parse(function_call['arguments'])
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
