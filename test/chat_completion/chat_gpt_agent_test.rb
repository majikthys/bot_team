# frozen_string_literal: true

require 'test_helper'

describe ChatGptAgent do
  it 'initializes from config' do
    agent = ChatGptAgent.new(config_path: 'test/config/test_agents/switchboard.yml')
    _(agent.model).must_equal 'gpt-3.5-turbo-0613'
    _(agent.system_directives).must_match(/^Your are an agent that classifies/)
  end

  describe 'implied_functions' do
    it 'returns expected functions for switchboard' do
      agent = ChatGptAgent.new(config_path: 'test/config/test_agents/switchboard.yml')
      _(agent.implied_functions.sort).must_equal %i[thanks]
    end

    it 'returns expected functions for leaf' do
      agent = ChatGptAgent.new(config_path: 'test/config/test_agents/leaf.yml')
      _(agent.implied_functions.sort).must_equal %i[set_test_value]
    end
  end
end
