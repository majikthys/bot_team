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

