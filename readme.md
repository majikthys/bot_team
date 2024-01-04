
# Why
Bot Team? is a library to make it easier to facilitate openai GPT Chat Completion scenarios that
benefit from multiple passes with Chat Completion focused prompts at each step. 

A typical example usage example would be to run a user message through several exchanges with chat gpt such as:

### Step 1) Bouncer
This prompt would be tailored to only discern if the user is attempting to manipulate or hack the chat interface.
Assuming no hacking is detected, the user message would be handed directly to a switchboard assistant.

### Step 2) Switchboard
This prompt would discern what of many topics the user message might be requesting. 
A typical switch board would take rudimentary direct action (like 'unsubscribe') or hand off to a topic agent

### Step 3) Topic agent
A Topic agent would be narrowly scoped to  


## Benefits of Progression through Narrow Scoped Agents
1) Narrowly scoped assistant prompts are easier to test and refine.
2) Curtail the assistant's access to data to only information required for the topic at hand, which can prevent PII leaks.
3) Curtail the assistant's access to functions to only those required to fulfill the objective
4) Use GPT engines and resources tuned to the current narrow scope. For example switchboard and bouncer functions can be completed excellently with 3.5, while only some topic assistants might need more expensive models.
5) Novel multipass solution architectures, like true Chain of Thought

# How
