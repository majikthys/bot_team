
module Switchboard
  REQUEST_TYPE_METHODS = {
    "set test value" => { agent: :leaf },
    "generic away message (e.g. I am driving)" => { ignore: :away },
    "spam" => { ignore: :spam },
    "other" => { ignore: :other }
  }.freeze

  def set_request_type(request_type:, sentiment:, classification_confidence:)
    if REQUEST_TYPE_METHODS[request_type][:agent]
      call_agent(
        agent: REQUEST_TYPE_METHODS[request_type][:agent],
        sentiment:,
        classification_confidence:
      )
    end
  end

  def call_agent(agent:, sentiment:, classification_confidence:)
    log_action("call_agent with #{agent} #{sentiment} #{classification_confidence}")
    next_agent = AgentFactory.new('test/config/test_agents/').create_agent(agent_name: agent, messages: self.chat_gpt_request.messages)
    next_agent.call
  end
end