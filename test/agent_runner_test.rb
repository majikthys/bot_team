require 'minitest/autorun'
require 'chat_completion/agent_runner'
require 'modules/leaf'
require 'modules/switchboard'

describe AgentRunner do
  $LOAD_PATH << 'test/modules' unless $LOAD_PATH.include?('test/modules')
  def setup
    @subject = AgentRunner.new(config_root: 'test/config/test_agents/', modules: [Leaf, Switchboard])
  end

  it 'should run team of agents' do
    @subject.initial_agent_name = 'switchboard'
    @subject.initial_messages = [{role: 'user', content: 'set test value to 99'}]
    result = @subject.run_team

    # Demonstrates that switchboard called leaf
    assert_equal "OUTPUT FROM THE LEAF FUNCTION", result
  end

  it 'should run single agent' do
    result = @subject.run_agent(agent_name: 'leaf', messages: [{role: 'user', content: 'set test value to 99'}])
    assert_equal "OUTPUT FROM THE LEAF FUNCTION", result
  end

  it 'should be instantiated with modules' do
    assert @subject.respond_to?(:set_test_value), "@subject should respond to :change_state"
  end

  it 'loads modules' do
    runner = AgentRunner.new(config_root: 'test/config/test_agents/')

    refute runner.respond_to?(:set_test_value), "@subject should not respond to :change_state"
    runner.load_modules([Leaf])
    assert runner.respond_to?(:set_test_value), "@subject should respond to :change_state"
  end

  it 'should create leaf agent' do
    agent = @subject.create_agent(agent_name: 'leaf')
    assert_equal 'gpt-3.5-turbo-0613', agent.chat_gpt_request.model
    assert_equal 80, agent.chat_gpt_request.max_tokens
    assert_equal 1, agent.chat_gpt_request.messages.count
    assert_equal 1, agent.chat_gpt_request.functions.count
  end

  it 'should create switchboard agent' do
    agent = @subject.create_agent(agent_name: 'switchboard')
    assert_equal 'gpt-3.5-turbo-0613', agent.chat_gpt_request.model
    assert_equal ({:name=>"set_request_type"}), agent.chat_gpt_request.function_call
    assert_equal 80, agent.chat_gpt_request.max_tokens
    assert_equal 1, agent.chat_gpt_request.messages.count
    assert_equal 1, agent.chat_gpt_request.functions.count
  end
end
