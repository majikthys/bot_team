#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to create a test batch for recording the #results VCR cassette
# Usage: OPENAI_API_KEY=$(cat ../../../tmp/openai_api_key.txt) ruby test/create_test_batch.rb

require_relative '../lib/bot_team'

api_key = ENV['OPENAI_API_KEY']
unless api_key
  puts "ERROR: OPENAI_API_KEY not set"
  puts "Run with: OPENAI_API_KEY=$(cat ../../../tmp/openai_api_key.txt) ruby test/create_test_batch.rb"
  exit 1
end

# Create a simple batch with one request
jsonl = '{"custom_id":"req_1","method":"POST","url":"/v1/chat/completions","body":{"model":"gpt-4o-mini","messages":[{"role":"user","content":"Say hello"}]}}'

puts "Creating test batch..."
batch = ChatGptBatch.submit(jsonl, api_key: api_key)

puts "\n✅ Batch created successfully!"
puts "Batch ID: #{batch.id}"
puts "Status: #{batch.status}"
puts "Created at: #{batch.created_at}"
puts "\nTo check status:"
puts "  OPENAI_API_KEY=$(cat ../../../tmp/openai_api_key.txt) ruby test/check_batch_status.rb #{batch.id}"
puts "\nOnce completed, record the cassette with:"
puts "  OPENAI_API_KEY=$(cat ../../../tmp/openai_api_key.txt) COMPLETED_BATCH_ID=#{batch.id} RUN_INTEGRATION_TESTS=1 bundle exec ruby -Itest test/bot_team/chat_gpt_batch_test.rb --name='/results/'"
