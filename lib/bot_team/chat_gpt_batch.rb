# frozen_string_literal: true

require "httparty"
require "tempfile"
require "json"

# Interface for OpenAI Batch API
# Allows submitting multiple chat completion requests as a batch
# and retrieving results asynchronously
#
# @see https://platform.openai.com/docs/api-reference/batch
class ChatGptBatch
  attr_reader :id, :status, :created_at, :request_counts, :metadata

  # Submit a new batch to OpenAI
  #
  # @param jsonl_string [String] JSONL-formatted batch requests
  # @param api_key [String] OpenAI API key (defaults to BotTeam config)
  # @return [ChatGptBatch] The created batch instance
  def self.submit(jsonl_string, api_key: nil)
    api_key ||= BotTeam.configuration.api_key

    # Upload JSONL file
    file_response = upload_file(jsonl_string, api_key:)
    file_id = file_response["id"]

    # Create batch
    batch_response = create_batch(file_id, api_key:)

    new(batch_response, api_key:)
  end

  # Load an existing batch from OpenAI
  #
  # @param batch_id [String] OpenAI batch ID
  # @param api_key [String] OpenAI API key (defaults to BotTeam config)
  # @return [ChatGptBatch] The batch instance
  def self.find(batch_id, api_key: nil)
    api_key ||= BotTeam.configuration.api_key
    batch_response = get_batch_status(batch_id, api_key:)
    new(batch_response, api_key:)
  end

  def initialize(batch_data, api_key:)
    @api_key = api_key
    update_from_response(batch_data)
  end

  # Refresh batch status from OpenAI
  #
  # @return [self]
  def refresh
    batch_response = self.class.get_batch_status(@id, api_key: @api_key)
    update_from_response(batch_response)
    self
  end

  # Check if batch is completed
  #
  # @return [Boolean]
  def completed?
    @status == :completed
  end

  # Check if batch failed
  #
  # @return [Boolean]
  def failed?
    @status == :failed || @status == :expired || @status == :cancelled
  end

  # Retrieve batch results (only valid when completed)
  #
  # @return [String] JSONL string of results
  # @raise [RuntimeError] if batch is not completed
  def results
    raise "Batch not completed (status: #{@status})" unless completed?

    output_file_id = @output_file_id
    raise "No output file available" unless output_file_id

    self.class.get_file_content(output_file_id, api_key: @api_key)
  end

  # Get error message (only valid when failed)
  #
  # @return [String, nil] Error message if failed
  def error_message
    @error_message
  end

  # Cancel the batch
  #
  # @return [self]
  def cancel
    batch_response = self.class.cancel_batch(@id, api_key: @api_key)
    update_from_response(batch_response)
    self
  end

  private

  def update_from_response(batch_data)
    # Handle error responses from OpenAI
    if batch_data["error"]
      error_msg = batch_data.dig("error", "message") || batch_data["error"].to_s
      raise "OpenAI API error: #{error_msg}"
    end

    @id = batch_data["id"]
    @status = batch_data["status"]&.to_sym
    @created_at = Time.at(batch_data["created_at"]) if batch_data["created_at"]
    @request_counts = batch_data["request_counts"]
    @metadata = batch_data["metadata"]
    @output_file_id = batch_data["output_file_id"]
    @error_file_id = batch_data["error_file_id"]

    # Extract error message if present
    if batch_data["errors"] && batch_data["errors"].any?
      @error_message = batch_data["errors"].map { |e| e["message"] }.join("; ")
    end
  end

  # Upload JSONL file to OpenAI
  #
  # @param jsonl_string [String] JSONL content
  # @param api_key [String] OpenAI API key
  # @return [Hash] File upload response
  def self.upload_file(jsonl_string, api_key:)
    # Create temporary file
    file = Tempfile.new(["batch_input", ".jsonl"])
    begin
      file.write(jsonl_string)
      file.rewind

      # Upload via multipart form data using HTTParty
      response = HTTParty.post(
        "https://api.openai.com/v1/files",
        headers: { "Authorization" => "Bearer #{api_key}" },
        multipart: true,
        body: {
          file: file,
          purpose: "batch"
        }
      )

      JSON.parse(response.body)
    ensure
      file.close
      file.unlink
    end
  end

  # Create batch with uploaded file
  #
  # @param file_id [String] Uploaded file ID
  # @param api_key [String] OpenAI API key
  # @return [Hash] Batch creation response
  def self.create_batch(file_id, api_key:)
    response = HTTParty.post(
      "https://api.openai.com/v1/batches",
      headers: {
        "Authorization" => "Bearer #{api_key}",
        "Content-Type" => "application/json"
      },
      body: {
        input_file_id: file_id,
        endpoint: "/v1/chat/completions",
        completion_window: "24h"
      }.to_json
    )

    JSON.parse(response.body)
  end

  # Get batch status from OpenAI
  #
  # @param batch_id [String] Batch ID
  # @param api_key [String] OpenAI API key
  # @return [Hash] Batch status response
  def self.get_batch_status(batch_id, api_key:)
    response = HTTParty.get(
      "https://api.openai.com/v1/batches/#{batch_id}",
      headers: { "Authorization" => "Bearer #{api_key}" }
    )

    JSON.parse(response.body)
  end

  # Get file content from OpenAI
  #
  # @param file_id [String] File ID
  # @param api_key [String] OpenAI API key
  # @return [String] File content
  def self.get_file_content(file_id, api_key:)
    response = HTTParty.get(
      "https://api.openai.com/v1/files/#{file_id}/content",
      headers: { "Authorization" => "Bearer #{api_key}" }
    )

    response.body
  end

  # Cancel a batch
  #
  # @param batch_id [String] Batch ID
  # @param api_key [String] OpenAI API key
  # @return [Hash] Cancel response
  def self.cancel_batch(batch_id, api_key:)
    response = HTTParty.post(
      "https://api.openai.com/v1/batches/#{batch_id}/cancel",
      headers: {
        "Authorization" => "Bearer #{api_key}",
        "Content-Type" => "application/json"
      },
      body: "{}"
    )

    JSON.parse(response.body)
  end
end
