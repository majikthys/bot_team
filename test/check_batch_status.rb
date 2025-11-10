#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to check the status of a batch
# Usage: OPENAI_API_KEY=$(cat ../../../tmp/openai_api_key.txt) ruby test/check_batch_status.rb BATCH_ID

require_relative '../lib/bot_team'

api_key = ENV['OPENAI_API_KEY']
unless api_key
  puts "ERROR: OPENAI_API_KEY not set"
  puts "Run with: OPENAI_API_KEY=$(cat ../../../tmp/openai_api_key.txt) ruby test/check_batch_status.rb BATCH_ID"
  exit 1
end

batch_id = ARGV[0]
unless batch_id
  puts "ERROR: Batch ID required"
  puts "Usage: OPENAI_API_KEY=$(cat ../../../tmp/openai_api_key.txt) ruby test/check_batch_status.rb BATCH_ID"
  exit 1
end

puts "Checking batch #{batch_id}..."
batch = ChatGptBatch.find(batch_id, api_key: api_key)

puts "\nBatch Status:"
puts "  ID: #{batch.id}"
puts "  Status: #{batch.status}"
puts "  Created: #{batch.created_at}"

if batch.request_counts
  puts "  Request counts:"
  batch.request_counts.each do |key, value|
    puts "    #{key}: #{value}"
  end
end

if batch.completed?
  puts "\n✅ Batch is COMPLETED! Ready to record cassette."
  puts "\nRecord the cassette with:"
  puts "  OPENAI_API_KEY=$(cat ../../../tmp/openai_api_key.txt) COMPLETED_BATCH_ID=#{batch_id} RUN_INTEGRATION_TESTS=1 bundle exec ruby -Itest test/bot_team/chat_gpt_batch_test.rb --name='/results/'"
elsif batch.failed?
  puts "\n❌ Batch FAILED"
  puts "Error message: #{batch.error_message}" if batch.error_message
else
  puts "\n⏳ Batch still processing (#{batch.status})"
  puts "\nCheck again in a few minutes with:"
  puts "  OPENAI_API_KEY=$(cat ../../../tmp/openai_api_key.txt) ruby test/check_batch_status.rb #{batch_id}"
end
