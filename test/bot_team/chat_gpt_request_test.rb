# frozen_string_literal: true

require "test_helper"

describe ChatGptRequest do
  subject { ChatGptRequest.new }

  it "should initialize with defaults" do
    assert_equal "gpt-3.5-turbo", subject.model
    assert_equal 80, subject.max_tokens
    assert_empty subject.messages
    assert_empty subject.functions
  end

  it "should replace system directives" do
    subject.add_system_message("MESSAGE1")
    subject.add_user_message("STAYS IN PLACE")
    subject.replace_system_directives("MESSAGE2")

    assert_equal([ { content: "MESSAGE2", role: "system" } ], subject.messages.select { |c| c[:role] == "system" })
    assert_equal({ role: "user", content: "STAYS IN PLACE" }, subject.messages.last)
  end

  it "should append system directives" do
    subject.add_system_message("PART1")
    subject.append_system_directives("PART2")

    assert_equal({ role: "system", content: "PART1\nPART2" }, subject.messages.last)
  end

  it "should add system message" do
    subject.add_system_message("TEST")
    subject.add_system_message("TEST2")

    assert_equal(
      [
        { content: "TEST", role: "system" },
        { content: "TEST2", role: "system" }
      ],
      subject.messages.select do |c|
        c[:role] == "system"
      end
    )
  end

  it "should add agent message" do
    subject.add_agent_message("TEST")

    assert_equal({ role: "assistant", content: "TEST" }, subject.messages.last)
  end

  it "should add user message" do
    subject.add_user_message("TEST")

    assert_equal({ role: "user", content: "TEST" }, subject.messages.last)
  end

  it "should initialize from agent" do
    agent = ChatGptAgent.new(
      model: "model",
      max_tokens: 100,
      functions: %w[function1 function2],
      forward_functions: %w[forward_function1 forward_function2],
      function_call: "function_call",
      system_directives: "system_directives"
    )
    subject.initialize_from_agent(agent)

    assert_equal "model", subject.model
    assert_equal 100, subject.max_tokens
    assert_equal %w[function1 function2 forward_function1 forward_function2], subject.functions
    assert_equal "function_call", subject.function_call
    assert_equal [ { role: "system", content: "system_directives" } ], subject.messages
  end
end
