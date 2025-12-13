# frozen_string_literal: true

require "test_helper"

describe ChatGptResponse do
  it "returns nil for message when content is empty string" do
    # OpenRouter returns empty string for content when tool_calls are present
    # OpenAI returns null. Both should be treated as nil to allow function processing.
    response = ChatGptResponse.new(
      choices: [
        {
          "message" => {
            "content" => "",
            "tool_calls" => [
              {
                "function" => {
                  "name" => "increment",
                  "arguments" => '{"by": 1}'
                }
              }
            ]
          }
        }
      ]
    )

    _(response.message).must_be_nil
    _(response.function_call).wont_be_nil
    _(response.function_call["name"]).must_equal "increment"
  end

  it "returns nil for message when content is null" do
    response = ChatGptResponse.new(
      choices: [
        {
          "message" => {
            "content" => nil,
            "tool_calls" => [
              {
                "function" => {
                  "name" => "increment",
                  "arguments" => '{"by": 1}'
                }
              }
            ]
          }
        }
      ]
    )

    _(response.message).must_be_nil
    _(response.function_call).wont_be_nil
  end

  it "returns content when message has actual text" do
    response = ChatGptResponse.new(
      choices: [
        {
          "message" => {
            "content" => "Hello, world!"
          }
        }
      ]
    )

    _(response.message).must_equal "Hello, world!"
  end
end
