# frozen_string_literal: true

require 'test_helper'

describe ChatGptAgent do
  def setup
    VCR.insert_cassette('chat_gpt_agent')
  end

  def teardown
    VCR.eject_cassette
  end

  it 'initializes from config' do
    agent = ChatGptAgent.new(config_path: 'test/config/test_agents/switchboard.yml')
    _(agent.model).must_equal 'gpt-3.5-turbo'
    _(agent.system_directives).must_match(/^Your are an agent that classifies/)
  end

  it 'intitializes with library defaults' do
    model = BotTeam.configuration.model
    BotTeam.configure do |config|
      config.model = 'TEST_MODEL'
    end
    agent = ChatGptAgent.new
    _(agent.model).must_equal 'TEST_MODEL'
    BotTeam.configure do |config|
      config.model = model
    end
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
      agent.run(messages: [{ role: 'user', content: msg }])
      _(result).must_equal 'nice'
      result = nil
      agent.run(msg)
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
      agent.define_parameter(
        'report_behavior',
        'behavior',
        type: 'string',
        enum: %w[nice mean],
        required: true,
        description: 'the behavior the user is exhibiting'
      )
      _(agent.function_call).must_equal({name: 'report_behavior'})
      _(agent.function_procs.keys).must_equal([:report_behavior])
      _(agent.function_procs[:report_behavior]).must_be_kind_of(Proc)
      _(agent.functions).must_equal([report_behavior_function_def])
      _(agent.functions.first[:parameters][:properties].keys).must_equal([:behavior])
      _(agent.functions.first[:parameters][:required]).must_equal(['behavior'])
      behavior = agent.functions.first[:parameters][:properties][:behavior]
      _(behavior[:type]).must_equal('string')
      _(behavior[:enum]).must_equal(%w[nice mean])
      _(behavior[:description]).must_equal('the behavior the user is exhibiting')

      msg = "I wanted you to know that I really appreciate you and I'm glad you're here"\
        ' and I hope you have a great day. Would you like a piece of cake?'
      agent.run(messages: [{role: 'user', content: msg}])
      _(result).must_equal 'nice'
      result = nil
      msg = "You're a terrible person and I hate you. I hope you get a bad headache."
      agent.run(messages: [{role: 'user', content: msg}])
      _(result).must_equal 'mean'
    end

    it 'can ask for multiple choices' do
      agent = ChatGptAgent.new(
        config: {
          num_choices: 3
        }
      )
      agent.run(messages: [{role: 'user', content: 'Give me a good name for a very cute puppy'}])
      _(agent.response.choices.size).must_equal 3
    end

    it 'will run the function_proc for each choice' do
      result = []
      agent = ChatGptAgent.new(
        config: {
          num_choices: 3
        }
      )
      agent.add_function('suggest_puppy_name', required: true) do |puppy_name:|
        result << puppy_name
      end
      agent.define_parameter('suggest_puppy_name', 'puppy_name', type: 'string', required: true)
      agent.run(messages: [{role: 'user', content: 'Come up with a good name for a very cute puppy and suggest it by calling suggest_puppy_name'}])
      _(result.size).must_equal 3
    end
  end

  def foo(bar:, baz: 'default')
    bar + baz
  end

  it "can infer the function name when given a method" do
    agent = ChatGptAgent.new
    agent.add_function(required: true, method: method(:foo))
    _(agent.function_call).must_equal({ name: 'foo' })
    _(agent.function_procs.keys).must_equal([:foo])
    _(agent.function_procs[:foo]&.respond_to?(:call)).must_be(:==, true)
  end

  it "can infer the parameters from the method signature" do
    agent = ChatGptAgent.new
    agent.add_function(method: method(:foo))
    _(agent.functions.first[:parameters][:properties].keys).must_equal(%i[bar baz])
    _(agent.functions.first[:parameters][:required]).must_equal(['bar'])
    properties = agent.functions.first[:parameters][:properties]
    _(properties[:bar][:type]).must_equal('string')
    _(properties[:baz][:type]).must_equal('string')
  end

  it "can be given descriptions and type details for parameters" do
    agent = ChatGptAgent.new
    agent.add_function('foo', required: true) { |bar:| bar }
    agent.define_parameter('foo', 'bar', type: 'integer', description: 'the bar')
    _(agent.functions.first[:parameters][:properties][:bar][:type]).must_equal('integer')
    _(agent.functions.first[:parameters][:properties][:bar][:description]).must_equal('the bar')
  end

  it "will raise an error if the method has positional arguments" do
    agent = ChatGptAgent.new
    _{
      agent.add_function('bad_proc') { |positional| positional }
    }.must_raise(ArgumentError)
  end

  it "will raise an error if no name is given and the method is a proc" do
    agent = ChatGptAgent.new
    _{
      agent.add_function { |bar:| bar }
    }.must_raise(ArgumentError)
  end
end
