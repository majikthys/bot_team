require 'minitest/autorun'
require 'chat_completion/agent_factory'

describe AgentFactory do
  $LOAD_PATH << 'test/modules' unless $LOAD_PATH.include?('test/modules')
  def setup
    @subject = AgentFactory.new('test/config/test_agents/')
  end

  it 'should initialize with defaults' do
    assert_equal 'test/config/test_agents/', @subject.config_root
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

  it 'should create switchboard agent and leaf agent' do
    agent = @subject.create_agent(agent_name: 'switchboard')
    agent.chat_gpt_request.add_user_message("set test value to 99")

    result = agent.call
    assert_equal "EXPECTED VALUE", result
  end

end
