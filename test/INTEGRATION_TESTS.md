# Running Integration Tests for ChatGptBatch

The ChatGptBatch integration tests interact with the real OpenAI Batch API to record VCR cassettes. These cassettes are then used for future test runs without hitting the API.

## Prerequisites

1. **OpenAI API Key**: You need a valid OpenAI API key with access to the Batch API
2. **Environment Variables**: Set `OPENAI_API_KEY` in your environment

## Recording VCR Cassettes

### Step 1: Set Your API Key

```bash
export OPENAI_API_KEY=your_actual_api_key_here
```

### Step 2: Run Integration Tests

To run all integration tests and record cassettes:

```bash
cd lib/bot_team
RUN_INTEGRATION_TESTS=1 bundle exec ruby -Itest test/bot_team/chat_gpt_batch_test.rb
```

To run a specific integration test:

```bash
RUN_INTEGRATION_TESTS=1 bundle exec ruby -Itest test/bot_team/chat_gpt_batch_test.rb --name="/submit/"
```

### Step 3: Understanding the Tests

**Note on batch state changes**: OpenAI batches go through different states:
- `validating` → `in_progress` → `finalizing` → `completed`
- or `validating` → `cancelling` → `cancelled` (if canceled)

Some cassettes may need multiple recording attempts:

#### Test: `.submit`
- Creates a new batch and records the response
- Usually succeeds on first attempt
- Batch will be in `validating` or `in_progress` state

#### Test: `.find`
- Creates a batch, then loads it by ID
- Should succeed on first attempt

#### Test: `#refresh`
- Creates a batch and refreshes its status
- Should succeed on first attempt

#### Test: `#cancel`
- Creates a batch and cancels it
- Should succeed on first attempt
- Final status will be `cancelling` or `cancelled`

#### Test: `#results` (Requires Special Handling)
- **This test requires a completed batch**
- Two approaches:

  **Approach 1: Wait for completion**
  1. Create a batch manually via the OpenAI dashboard or API
  2. Wait for it to complete (can take minutes to hours depending on OpenAI load)
  3. Set the batch ID in environment: `export COMPLETED_BATCH_ID=batch_xxx`
  4. Run the test to record the cassette

  **Approach 2: Use a previously completed batch**
  1. Check OpenAI dashboard for a completed batch from a previous run
  2. Set `COMPLETED_BATCH_ID` to that batch ID
  3. Record the cassette with that batch

## Verifying Cassettes

After recording, verify all tests pass using the cassettes:

```bash
bundle exec rake test
```

You should see:
- 62 runs, 134 assertions, 0 failures, 0 errors, 5 skips

The 5 skips are the integration tests (they only run when `RUN_INTEGRATION_TESTS=1`).

## VCR Cassette Locations

Cassettes are stored in:
```
lib/bot_team/test/vcr_cassettes/
├── chat_gpt_batch_submit.yml
├── chat_gpt_batch_find.yml
├── chat_gpt_batch_refresh.yml
├── chat_gpt_batch_cancel.yml
└── chat_gpt_batch_results.yml
```

## Sensitive Data

VCR is configured to filter your API key from cassettes:
- Your real API key is replaced with `<OPENAI_API_KEY>` in recorded cassettes
- Safe to commit cassettes to git

## Cost Considerations

- Each batch submission costs the same as the individual requests it contains
- For testing, use minimal requests (single simple message)
- Cancel batches promptly if you don't need results
- The test suite uses `gpt-4o-mini` to minimize costs

## Troubleshooting

**Error: "Incorrect API key provided"**
- Make sure `OPENAI_API_KEY` is set in your environment
- Verify the key is valid and active

**Error: "Batch not completed"**
- This is expected for the `#results` test
- You need to wait for a batch to complete or use `COMPLETED_BATCH_ID`

**Tests fail with VCR cassettes**
- Delete cassettes: `rm test/vcr_cassettes/chat_gpt_batch_*.yml`
- Re-record them following steps above
