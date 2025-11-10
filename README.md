# Bot Team

A simple way to set up special purpose agents for use in ruby code

# Talk to OpenAI

With 'OPENAI_API_KEY' set in your environment, you are ready to go.

```ruby
ChatGptAgent.new.run("Make me a sandwich")
#=> "I'm happy to help with that! What kind of sandwich would you like?"
```

These, and other settings, can be set independantly by agent:

```ruby
agent =
  ChatGptAgent.new(
    model: 'gpt-3.5-turbo',
    max_tokens: 200,
    system_directives: <<~PROMPT
      You are a friendly, helpful assistant, ready to answer questions,
      but every answer you give is in pig latin.
    PROMPT
  )
agent.run("What's the easiest way to clean your toenails?")
#=> "eThay easiestway ayway otay eanclay ouryay oenailstay isway otay useway a oodgay ailbruhbray ithway omesay aterway andway oapsay."
```

You can configure defaults for your project thusly:

```ruby
BotTeam.configure do |config|
  config.model = 'gpt-4-turbo-preview'
  config.max_tokens = 4096
  config.tempurature = 1.7
  config.num_choices = 3
  config.api_key = `cat tmp/api_key.txt`.strip # but it's better to use ENV
end
```

Using tools is as simple as a ruby method (but be warned, all the arguments must be keyword arguments):

```ruby
def alert(message:)
  puts "!!!!!!!! #{message} !!!!!!!!"
end

agent = ChatGptAgent.new
agent.add_function(method: method(:alert))
agent.run("Say something alarming")
# !!!!!!!! Warning: This is a test of the emergency alert system. This is only a test. !!!!!!!!
#=> [nil]
```

## Usage Tracking and Cost Calculation

BotTeam automatically tracks token usage and calculates costs for OpenAI API calls. Access usage information at both the individual agent and runner levels.

### Individual Agent Usage

After running an agent, access usage stats and cost:

```ruby
agent = ChatGptAgent.new
agent.run("Say hello")

agent.usage
#=> {"prompt_tokens" => 10, "completion_tokens" => 5, "total_tokens" => 15, ...}

agent.cost
#=> 0.000015
```

### AgentRunner Cumulative Usage

When using AgentRunner with cascading agents, usage is automatically aggregated across all agent calls:

```ruby
runner = AgentRunner.new(
  config_root: "config/agents/",
  modules: [MyModule]
)
runner.initial_agent_name = "switchboard"
runner.initial_messages = [{ role: "user", content: "Process this request" }]
runner.run_team

runner.usage_stats
#=> {"gpt-4o" => {"default" => {input: 443, input_cached: 0, output: 34, total: 477}}}

runner.total_cost
#=> 0.000272
```

The `usage_stats` hash tracks token counts by model and service tier, breaking down:
- `input`: Uncached prompt tokens
- `input_cached`: Cached prompt tokens
- `output`: Completion tokens
- `total`: Total tokens used

AgentRunner automatically logs cumulative usage at DEBUG level when `run_team` completes.

### Pricing Data

Pricing information is stored in `lib/bot_team/chat_gpt_cost.csv` and covers all OpenAI models and service tiers (batch, flex, standard, priority). You can override this by placing a custom CSV at `config/chat_gpt_cost.csv` in your project.

