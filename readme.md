
# Why
Bot Team? is a library to make it easier to facilitate openai GPT Chat Completion scenarios that
benefit from multiple passes with Chat Completion. 

## Benefits of Progression through Narrow Scoped Agents
1) Narrowly scoped assistant prompts are easier to test and refine.
2) Curtail the assistant's access to data to only information required for the topic at hand, which can prevent PII leaks.
3) Curtail the assistant's access to functions to only those required to fulfill the objective
4) Use GPT engines and resources tuned to the current narrow scope. For example switchboard and bouncer functions can be completed excellently with 3.5, while only some topic assistants might need more expensive models.
5) Novel multipass solution architectures, like true Chain of Thought

## A Typical Scenario
A typical example usage example would be to run a user message through several exchanges with chat gpt such as:

### Step 1) Bouncer
This prompt would be tailored to only discern if the user is attempting to manipulate or hack the chat interface.
Assuming no hacking is detected, the user message would be handed directly to a switchboard assistant.

### Step 2) Switchboard
This prompt would discern what of many topics the user message might be requesting. 
A typical switch board would take rudimentary direct action (like 'unsubscribe') or hand off to a topic agent

### Step 3) Topic agent
A Topic agent would be narrowly scoped to  


# How


## Ability Modules and Functions
Modules passed into TeamRunner at instantiation are available for use by agents when also defined in 
the agent's config in the ```functions``` section.

The ```functions``` and ```function_call``` section of agent config maintains parity with the [OpenAI API](https://platform.openai.com/docs/api-reference/chat/create#chat-create-functions). 

### example:
```yaml
:functions:
  - :name: get_product_info
    :description: get description of the product
    :parameters:
      :type: object
      :properties:
        :product_id:
          :type: string
          :description: id of the product
        :session_id:
          :type: string
          :description: the session id
      :required:
        - id
:function_call: auto
```
### State Map Functions
This is a powerful concept, which makes it easy for one agent to hand off to other agents based on 
a ChatGPT function.  

```state_map``` establishes a mapping between values that ChatGPT might return in a function call response and
agents to call.

For example, below is a state map will hand off to different agents based if 
ChatGPT calls the function ```set_request_type``` with the argument ```request_type```.

```yaml
:state_map:
  :function_name: :set_request_type
  :argument_name: :request_type
  :values_map:
    :get product info:
      :agent: :product_info
    :file complaint:
      :agent: :customer_service
```
In this example, if the value of ```request_type``` is ```get product info``` then  ```product_info``` agent
will be created and message history will be handed over to it.

But, if the value of ```request_type``` is ```file complaint``` then  ```customer_service``` agent
will be created and message history will be handed over to it.


