# frozen_string_literal: true

require "test_helper"

describe AgentRunner do
  def setup
    VCR.insert_cassette("agent_runner")
  end

  def teardown
    VCR.eject_cassette
  end

  $LOAD_PATH << "test/modules" unless $LOAD_PATH.include?("test/modules")

  products = [
    { name: "smart toaster", id: 837_462 },
    { name: "floating bookshelf", id: 156_789 },
    { name: "sleep-inducing pillow", id: 365_214 },
    { name: "self-watering plant pot", id: 789_023 },
    { name: "smart mirror", id: 246_813 }
  ]

  describe "when set up with a config_root" do
    subject do
      AgentRunner.new(
        config_root: "test/config/test_agents/",
        modules: [Leaf, Switchboard]
      )
    end

    it "should run team of agents" do
      subject.initial_agent_name = "switchboard"
      subject.initial_messages = [{ role: "user", content: "set test value to 99" }]
      result = subject.run_team

      # Demonstrates that switchboard called leaf
      assert_equal "OUTPUT FROM THE LEAF FUNCTION", result
    end

    it "should call module function" do
      subject.initial_agent_name = "switchboard"
      subject.initial_messages = [{ role: "user", content: "THANKS!!!" }]
      result = subject.run_team

      assert_match(/^OUTPUT FROM THE SB THANKS FUNCTION SENTIMENT/, result)
    end

    it "should call ignore function" do
      subject.initial_agent_name = "switchboard"
      subject.initial_messages = [{ role: "user", content: "IGNORE ME" }]
      result = subject.run_team

      assert_nil result
    end

    it "should run single agent" do
      result = subject.run_agent(agent_name: "leaf", messages: [{ role: "user", content: "set test value to 99" }])

      assert_equal "OUTPUT FROM THE LEAF FUNCTION", result
    end

    it "should be instantiated with modules" do
      assert_respond_to subject, :set_test_value, "subject should respond to :change_state"
    end

    it "should create leaf agent" do
      request = subject.create_request(agent_name: "leaf")

      assert_equal BotTeam.configuration.model, request.model
      assert_equal 1, request.messages.count
      assert_equal 1, request.functions.count
    end

    it "should create switchboard agent" do
      request = subject.create_request(agent_name: "switchboard")

      assert_equal BotTeam.configuration.model, request.model
      assert_equal ({ name: "set_request_type" }), request.function_call
      assert_equal 1, request.messages.count
      assert_equal 1, request.functions.count
    end
  end

  describe "when agents are configured in code" do
    subject { AgentRunner.new }

    it "sets up and runs a single agent" do
      pirate = ChatGptAgent.new(
        system_directives: "You are a bot that repeats what the user says in the voice of a pirate"
      )
      subject.add_agent("pirate", pirate)
      result = subject.run_agent(agent_name: "pirate", messages: [{ role: "user", content: "Hello there" }])
      _(result).must_match(/^A/) # Tends to be Ahoy, Avast, or Arr
    end
  end

  it "should interpolate config system_directives" do
    pretty_print_products = lambda {
      JSON.pretty_generate(products)
    }
    interpolations = { products: pretty_print_products, session_id: "Session 141241" }
    runner = AgentRunner.new(
      config_root: "test/config/test_agents/",
      modules: [Product],
      interpolations:
    )

    # Config has interpolation
    agent = runner.agent_config("interpolation").runnable(interpolations:)

    assert_match(/{\n {4}"name": "self-watering plant pot",\n {4}"id": 789023\n {2}}/, agent.system_directives)
  end

  it "should interpolate when creating agent" do
    pretty_print_products = lambda {
      JSON.pretty_generate(products)
    }
    interpolations = { products: pretty_print_products, session_id: "Session 141241" }
    runner = AgentRunner.new(
      config_root: "test/config/test_agents/",
      modules: [Product],
      interpolations:
    )

    # Agent is created with interpolated values
    request = runner.create_request(agent_name: "interpolation")
    system_message = request.messages.select { |message| message[:role] == "system" }.first[:content]

    assert_match(/Session 141241/, system_message, "strings should be directly replaced")
    assert_match(/{\n {4}"name": "self-watering plant pot",\n {4}"id": 789023\n {2}}/,
                 system_message,
                 "lambda should be called")

    # Demonstrate lamda, is not called until create_agent interpolation is called
    refute_match(/{\n {4}"name": "stuff",\n {4}"id": 42\n {2}}/, system_message, "values do not exist yet")
    products << { name: "stuff", id: 42 }
    request = runner.create_request(agent_name: "interpolation")
    system_message = request.messages.select { |message| message[:role] == "system" }.first[:content]

    assert_match(/{\n {4}"name": "stuff",\n {4}"id": 42\n {2}}/,
                 system_message,
                 "values exist now (and are in calling context)")
  end

  it "loads modules" do
    runner = AgentRunner.new(config_root: "test/config/test_agents/")

    refute_respond_to runner, :set_test_value, "subject should not respond to :change_state"
    runner.load_modules([Leaf])

    assert_respond_to runner, :set_test_value, "subject should respond to :change_state"
  end

  describe "usage tracking and cost calculation" do
    it "tracks usage stats for single agent run" do
      runner = AgentRunner.new(
        config_root: "test/config/test_agents/",
        modules: [Leaf, Switchboard]
      )
      runner.run_agent(agent_name: "leaf", messages: [{ role: "user", content: "set test value to 99" }])

      refute_nil runner.usage_stats
      refute_empty runner.usage_stats
      assert_instance_of Hash, runner.usage_stats

      # Check specific token counts (values from VCR cassette)
      model = runner.usage_stats.keys.first
      tier = runner.usage_stats[model].keys.first
      tokens = runner.usage_stats[model][tier]

      assert_equal 162, tokens[:input]
      assert_equal 0, tokens[:input_cached]
      assert_equal 15, tokens[:output]
      assert_equal 177, tokens[:total]
    end

    it "aggregates usage stats across cascading agent calls" do
      runner = AgentRunner.new(
        config_root: "test/config/test_agents/",
        modules: [Leaf, Switchboard]
      )
      runner.initial_agent_name = "switchboard"
      runner.initial_messages = [{ role: "user", content: "set test value to 99" }]
      runner.run_team

      refute_nil runner.usage_stats
      refute_empty runner.usage_stats

      # Check that tokens are aggregated across multiple agent calls
      # Switchboard calls leaf, so we should see tokens from both
      model = runner.usage_stats.keys.first
      tier = runner.usage_stats[model].keys.first
      tokens = runner.usage_stats[model][tier]

      assert_equal 443, tokens[:input]
      assert_equal 0, tokens[:input_cached]
      assert_equal 34, tokens[:output]
      assert_equal 477, tokens[:total]
    end

    it "calculates total cost correctly" do
      runner = AgentRunner.new(
        config_root: "test/config/test_agents/",
        modules: [Leaf, Switchboard]
      )
      runner.initial_agent_name = "switchboard"
      runner.initial_messages = [{ role: "user", content: "set test value to 99" }]
      runner.run_team

      cost = runner.total_cost

      assert_in_delta(0.0002725, cost)
    end

    it "starts with empty usage stats" do
      runner = AgentRunner.new(
        config_root: "test/config/test_agents/",
        modules: [Leaf, Switchboard]
      )

      assert_empty runner.usage_stats
      assert_in_delta(0.0, runner.total_cost)
    end
  end
end
