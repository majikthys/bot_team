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

  describe 'runnable' do
    it 'returns a runnable agent with expected interpolations' do
      agent = ChatGptAgent.new(
        config: {
          system_directives: 'You are a bot that repeats what the user says while incorporating the phrase "%{required_word}"',
        }
      )
      runnable = agent.runnable(interpolations: {required_word: 'meow'})
      _(runnable.system_directives).must_match(/incorporating the phrase "meow"$/)
    end
  end
end
