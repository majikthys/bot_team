# frozen_string_literal: true

require 'test_helper'

describe AgentRunner do
  $LOAD_PATH << 'test/modules' unless $LOAD_PATH.include?('test/modules')

  products = [
    { name: 'smart toaster', id: 837_462 },
    { name: 'floating bookshelf', id: 156_789 },
    { name: 'sleep-inducing pillow', id: 365_214 },
    { name: 'self-watering plant pot', id: 789_023 },
    { name: 'smart mirror', id: 246_813 }
  ]

  subject do
    AgentRunner.new(
      config_root: 'test/config/test_agents/',
      modules: [Leaf, Switchboard]
    )
  end

  it 'should run team of agents' do
    subject.initial_agent_name = 'switchboard'
    subject.initial_messages = [{role: 'user', content: 'set test value to 99'}]
    result = subject.run_team

    # Demonstrates that switchboard called leaf
    assert_equal "OUTPUT FROM THE LEAF FUNCTION", result
  end

  it 'should call module function' do
    subject.initial_agent_name = 'switchboard'
    subject.initial_messages = [{role: 'user', content: 'THANKS!!!'}]
    result = subject.run_team

    assert_match /^OUTPUT FROM THE SB THANKS FUNCTION SENTIMENT/, result
  end

  it 'should call ignore function' do
    subject.initial_agent_name = 'switchboard'
    subject.initial_messages = [{role: 'user', content: 'IGNORE ME'}]
    result = subject.run_team

    assert_nil result
  end

  it 'should run single agent' do
    result = subject.run_agent(agent_name: 'leaf', messages: [{role: 'user', content: 'set test value to 99'}])
    assert_equal "OUTPUT FROM THE LEAF FUNCTION", result
  end

  it 'should be instantiated with modules' do
    assert subject.respond_to?(:set_test_value), "subject should respond to :change_state"
  end

  it 'loads modules' do
    runner = AgentRunner.new(config_root: 'test/config/test_agents/')

    refute runner.respond_to?(:set_test_value), "subject should not respond to :change_state"
    runner.load_modules([Leaf])
    assert runner.respond_to?(:set_test_value), "subject should respond to :change_state"
  end

  it 'should create leaf agent' do
    agent = subject.create_agent(agent_name: 'leaf')
    assert_equal 'gpt-3.5-turbo-0613', agent.chat_gpt_request.model
    assert_equal 80, agent.chat_gpt_request.max_tokens
    assert_equal 1, agent.chat_gpt_request.messages.count
    assert_equal 1, agent.chat_gpt_request.functions.count
  end

  it 'should create switchboard agent' do
    agent = subject.create_agent(agent_name: 'switchboard')
    assert_equal 'gpt-3.5-turbo-0613', agent.chat_gpt_request.model
    assert_equal ({:name=>"set_request_type"}), agent.chat_gpt_request.function_call
    assert_equal 80, agent.chat_gpt_request.max_tokens
    assert_equal 1, agent.chat_gpt_request.messages.count
    assert_equal 1, agent.chat_gpt_request.functions.count
  end

  it 'should interpolate config system_directives' do
    pretty_print_products = lambda {
      JSON.pretty_generate(products)
    }
    interpolations = { products: pretty_print_products, session_id: 'Session 141241' }
    runner = AgentRunner.new(
      config_root: 'test/config/test_agents/',
      modules: [Product],
      interpolations:
    )

    # Config has interpolation
    config = runner.load_config('interpolation')
    assert_match /{\n {4}"name": "self-watering plant pot",\n {4}"id": 789023\n {2}}/, config[:system_directives]
  end

  it 'should interpolate when creating agent' do
    pretty_print_products = lambda {
      JSON.pretty_generate(products)
    }
    interpolations = { products: pretty_print_products, session_id: 'Session 141241' }
    runner = AgentRunner.new(
      config_root: 'test/config/test_agents/',
      modules: [Product],
      interpolations:
    )

    # Agent is created with interpolated values
    agent = runner.create_agent(agent_name: 'interpolation')
    system_message = agent.chat_gpt_request.messages.select { |message| message[:role] == 'system' }.first[:content]

    assert_match /Session 141241/, system_message, 'strings should be directly replaced'
    assert_match /{\n {4}"name": "self-watering plant pot",\n {4}"id": 789023\n {2}}/,
                 system_message,
                 'lambda should be called'

    # Demonstrate lamda, is not called until create_agent interpolation is called
    refute_match /{\n {4}"name": "stuff",\n {4}"id": 42\n {2}}/, system_message, 'values do not exist yet'
    products << { name: 'stuff', id: 42 }
    agent = runner.create_agent(agent_name: 'interpolation')
    system_message = agent.chat_gpt_request.messages.select { |message| message[:role] == 'system' }.first[:content]
    assert_match /{\n {4}"name": "stuff",\n {4}"id": 42\n {2}}/,
                 system_message,
                 'values exist now (and are in calling context)'
  end
end