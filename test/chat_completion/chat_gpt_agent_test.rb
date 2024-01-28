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
          system_directives: 'You are a bot that repeats what the user says '\
            'while incorporating the phrase "%{required_word}"',
        }
      )
      runnable = agent.runnable(interpolations: {required_word: 'meow'})
      _(runnable.system_directives).must_match(/incorporating the phrase "meow"$/)
    end
  end

  describe 'run' do
    let(:report_behavior_function_directive) do
      'You have to report if the user is being nice or mean'
    end
    let(:report_behavior_function_def) do
      {
        name: 'report_behavior',
        description: 'reports if the user is being nice or mean',
        parameters: {
          type: 'object',
          properties: {
            behavior: {
              type: 'string',
              description: 'the behavior the user is exhibiting',
              enum: %w[nice mean]
            }
          },
          required: ['behavior']
        }
      }
    end

    it 'will run a non-state map function' do
      result = nil
      agent = ChatGptAgent.new(
        config: {
          system_directives: report_behavior_function_directive,
          functions: [report_behavior_function_def],
          function_call: {
            name: 'report_behavior'
          },
          function_procs: {
            report_behavior: ->(behavior:) { result = behavior }
          }
        }
      )
      msg = "I wanted you to know that I really appreciate you and I'm glad you're here"\
        ' and I hope you have a great day. Would you like a piece of cake?'
      agent.run(messages: [{role: 'user', content: msg}])
      _(result).must_equal 'nice'
      result = nil
      msg = "You're a terrible person and I hate you. I hope you get a bad headache."
      agent.run(messages: [{role: 'user', content: msg}])
      _(result).must_equal 'mean'
    end

    it 'can define configs and functions through assignment' do
      result = nil
      agent = ChatGptAgent.new
      agent.system_directives = report_behavior_function_directive
      agent.add_function(
        'report_behavior',
        description: 'reports if the user is being nice or mean',
        required: true
      ) do |behavior:|
        result = behavior
      end
      agent.define_parameter('report_behavior', 'behavior', type: 'string', enum: %w[nice mean], required: true, description: 'the behavior the user is exhibiting')
      _(agent.function_call).must_equal({name: 'report_behavior'})
      _(agent.function_procs.keys).must_equal([:report_behavior])
      _(agent.function_procs[:report_behavior]).must_be_kind_of(Proc)
      _(agent.functions).must_equal([report_behavior_function_def])

      msg = "I wanted you to know that I really appreciate you and I'm glad you're here"\
        ' and I hope you have a great day. Would you like a piece of cake?'
      agent.run(messages: [{role: 'user', content: msg}])
      _(result).must_equal 'nice'
      result = nil
      msg = "You're a terrible person and I hate you. I hope you get a bad headache."
      agent.run(messages: [{role: 'user', content: msg}])
      _(result).must_equal 'mean'
    end
  end
end
