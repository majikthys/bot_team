# frozen_string_literal: true

require "test_helper"

describe ChatGptBatch do
  describe "initialization" do
    it "initializes with batch data" do
      batch_data = {
        "id" => "batch_123",
        "status" => "in_progress",
        "created_at" => Time.now.to_i,
        "request_counts" => { "total" => 10, "completed" => 5 }
      }

      batch = ChatGptBatch.new(batch_data, api_key: "test_key")

      _(batch.id).must_equal "batch_123"
      _(batch.status).must_equal :in_progress
      _(batch.request_counts).must_equal({ "total" => 10, "completed" => 5 })
    end
  end

  describe "#completed?" do
    it "returns true when status is completed" do
      batch = ChatGptBatch.new(
        { "id" => "batch_123", "status" => "completed" },
        api_key: "test_key"
      )

      _(batch.completed?).must_equal true
    end

    it "returns false when status is not completed" do
      batch = ChatGptBatch.new(
        { "id" => "batch_123", "status" => "in_progress" },
        api_key: "test_key"
      )

      _(batch.completed?).must_equal false
    end
  end

  describe "#failed?" do
    it "returns true for failed status" do
      batch = ChatGptBatch.new(
        { "id" => "batch_123", "status" => "failed" },
        api_key: "test_key"
      )

      _(batch.failed?).must_equal true
    end

    it "returns true for cancelled status" do
      batch = ChatGptBatch.new(
        { "id" => "batch_123", "status" => "cancelled" },
        api_key: "test_key"
      )

      _(batch.failed?).must_equal true
    end

    it "returns true for expired status" do
      batch = ChatGptBatch.new(
        { "id" => "batch_123", "status" => "expired" },
        api_key: "test_key"
      )

      _(batch.failed?).must_equal true
    end

    it "returns false for in_progress status" do
      batch = ChatGptBatch.new(
        { "id" => "batch_123", "status" => "in_progress" },
        api_key: "test_key"
      )

      _(batch.failed?).must_equal false
    end
  end

  describe "#results" do
    it "raises error when not completed" do
      batch = ChatGptBatch.new(
        { "id" => "batch_123", "status" => "in_progress" },
        api_key: "test_key"
      )

      error = _ { batch.results }.must_raise RuntimeError
      _(error.message).must_match(/not completed/)
    end

    it "raises error when no output file available" do
      batch = ChatGptBatch.new(
        { "id" => "batch_123", "status" => "completed" },
        api_key: "test_key"
      )

      error = _ { batch.results }.must_raise RuntimeError
      _(error.message).must_match(/No output file/)
    end
  end

  describe "#error_message" do
    it "returns nil when no errors" do
      batch = ChatGptBatch.new(
        { "id" => "batch_123", "status" => "in_progress" },
        api_key: "test_key"
      )

      _(batch.error_message).must_be_nil
    end

    it "returns error message when errors present" do
      batch = ChatGptBatch.new(
        {
          "id" => "batch_123",
          "status" => "failed",
          "errors" => [
            { "message" => "Error 1" },
            { "message" => "Error 2" }
          ]
        },
        api_key: "test_key"
      )

      _(batch.error_message).must_equal "Error 1; Error 2"
    end
  end

  # Integration tests with VCR
  # Note: These tests interact with the real OpenAI API
  # You'll need OPENAI_API_KEY set in your environment to record cassettes

  describe ".submit (integration)" do
    it "uploads file and creates batch" do
      VCR.use_cassette("chat_gpt_batch_submit", record: :none, match_requests_on: [:uri_and_multipart_files]) do
        jsonl = '{"custom_id":"req_1","method":"POST","url":"/v1/chat/completions","body":{"model":"gpt-4o-mini","messages":[{"role":"user","content":"Say hello"}]}}'

        batch = ChatGptBatch.submit(jsonl)

        _(batch.id).must_match(/^batch_/)
        _(batch.status).must_be_kind_of Symbol
        _(%i[validating in_progress finalizing completed]).must_include batch.status
      end
    end
  end

  describe ".find (integration)" do
    it "loads an existing batch" do
      VCR.use_cassette("chat_gpt_batch_find", record: :none, match_requests_on: [:uri_and_multipart_files]) do
        # First create a batch to find
        jsonl = '{"custom_id":"req_1","method":"POST","url":"/v1/chat/completions","body":{"model":"gpt-4o-mini","messages":[{"role":"user","content":"Say hello"}]}}'
        created_batch = ChatGptBatch.submit(jsonl)
        batch_id = created_batch.id

        # Now find it
        batch = ChatGptBatch.find(batch_id)

        _(batch.id).must_equal batch_id
        _(batch.status).must_be_kind_of Symbol
      end
    end
  end

  describe "#refresh (integration)" do
    it "updates batch status from server" do
      VCR.use_cassette("chat_gpt_batch_refresh", record: :none, match_requests_on: [:uri_and_multipart_files]) do
        # Create a batch
        jsonl = '{"custom_id":"req_1","method":"POST","url":"/v1/chat/completions","body":{"model":"gpt-4o-mini","messages":[{"role":"user","content":"Say hello"}]}}'
        batch = ChatGptBatch.submit(jsonl)

        original_status = batch.status

        # Refresh it
        batch.refresh

        # Status should still be a symbol (may or may not have changed)
        _(batch.status).must_be_kind_of Symbol
      end
    end
  end

  describe "#cancel (integration)" do
    it "cancels a batch" do
      VCR.use_cassette("chat_gpt_batch_cancel", record: :none, match_requests_on: [:uri_and_multipart_files]) do
        # Create a batch
        jsonl = '{"custom_id":"req_1","method":"POST","url":"/v1/chat/completions","body":{"model":"gpt-4o-mini","messages":[{"role":"user","content":"Say hello"}]}}'
        batch = ChatGptBatch.submit(jsonl)

        # Cancel it
        batch.cancel

        # Status should be cancelling or cancelled
        _(%i[cancelling cancelled]).must_include batch.status
      end
    end
  end

  describe "#results (integration)" do
    it "retrieves results from a completed batch" do
      VCR.use_cassette("chat_gpt_batch_results", record: :none, match_requests_on: [:uri_and_multipart_files]) do
        # This cassette was recorded with a completed batch
        # The batch ID is from the cassette and will be replayed by VCR
        batch_id = "batch_691100653714819085a1d9b57a239d50"
        batch = ChatGptBatch.find(batch_id)

        _(batch.completed?).must_equal true

        results = batch.results

        _(results).must_be_kind_of String
        _(results).must_match(/custom_id/) # JSONL format should contain custom_id
      end
    end
  end
end
