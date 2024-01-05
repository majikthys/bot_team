
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

[//]: # (THIS SHOULD REALLY HAVE A STATEMACHNINE DIAGRAM)

### Step 1) Bouncer
This prompt would be tailored to only discern if the user is attempting to manipulate or hack the chat interface.
Assuming no hacking is detected, the user message would be handed directly to a switchboard assistant.

### Step 2) Switchboard
This prompt would discern what of many topics the user message might be requesting.
A typical switch board would take rudimentary direct action (like 'unsubscribe') or hand off to a topic agent

### Step 3) Topic agent
A Topic agent would be narrowly scoped to a single topic, such as 'product info' or 'customer service'.

# Terminology
Where possible we will use terminology from the [OpenAI API](https://platform.openai.com/docs/api-reference/chat/create).

OpenAI API Terms of Note:
* **[Chat Completion (concept)](https://platform.openai.com/docs/guides/text-generation/chat-completions-api)**: A modality of OpenAI's GPT text generation
  * **[Chat Completion Request](https://platform.openai.com/docs/api-reference/chat/create)**: A data structure containing a request for Chat Completion
    * **Messages**: A list of messages containing the "conversation" history between roles, generally with the last message being the most recent user message.
      * **Role**: One of 4 roles associated with each message in message history.
        * **Assistant**: Messages and function calls produced by ChatGPT
        * **User**: Messages produced by human user
        * **System**: Prompts, or similar messages containing instructions and information to guide the ChatGPT Assistant
        * **Tool/Function**: Results of previous function calls
    * **Tools / Function**: Function definitions of functions within our application that are available for ChatGPT assistant to call.
  * **[Chat Completion Object/Response](https://platform.openai.com/docs/api-reference/chat/object)**: A data structure containing a response from Chat Completion, importantly including response messsage(s) or function/tool call(s)
    * **Message**: A textual response from ChatGPT
    * **Tool Call / Function Call**: A function call, with arguments to be executed in our application. 
  
  * **Assistant**: Note: Unfortunately, this an overloaded term. It may refer to the execution context within a Chat Completion exchange (as mentioned in above 'Role' definition) or it might refer to a [beta feature/api](https://platform.openai.com/docs/assistants/overview) which is similar but different enough to cause confusion.
 
 Gem Terms of 
 * **Agent**: A single session of Chat Completion. This includes:
   1) a Chat Completion Request with Messages/Prompts
   2) a Chat Completion Response with Message/Function Call
 * **Team**: A chain of Agents, to process a single user message and ultimately producing a single response (or possibly none).
 * **Config**: A hash structure containing configuration info used to create a Chat Completion, significantly including:
   * **System Directive**: Prompt/System Message, which may have tokens that will be replaced by via interpolation.
   * **Tools/Function Definition**: Tools/Function Messages
   * **State Map**: A mechanism to define 'switchboard' or state machine logic within a config (rather than in code).
  * And various facets of Chat Completion Requests, such as model, temperature, etc.
 * **Interpolations**: This is the mechanism by which one can insert user and session specific information into a System Directive at runtime. It is a map of keys and values/lamdas that will be used to replace tokens in a System Directive. 
 * **Ability Modules**: Modules containing functions that are made available to ChatGPT to call. These are passed into TeamRunner at instantiation and must be defined in the agent's config in the ```functions``` section.


Note about the term "**_Function_**": Function is obviously an overloaded term. We will refer to functions within the local application as "local functions", when there may be ambiguity.


# How To Use
## Hello World
> TODO: 
> * Add example directory with hello world-ish sample
> * Reference here

## Config
> TODO: 
>  * outline config sections
>  * yaml file locations
 
### System Directive & Interpolations
> TODO: simple example with both lambda and string interpolation

### Config Errata
> TODO: model, tokens, etc.

## Ability Modules and Functions
Modules passed into TeamRunner at instantiation are available for use by agents when also defined in the agent's config in the ```functions``` section.

The ```functions``` and ```function_call``` section of agent config maintains parity with the [OpenAI API](https://platform.openai.com/docs/api-reference/chat/create#chat-create-functions). 

The output of function will be rendered to user and may be text or nil.

>>> HEY MIKE, this is a hole in our implementation. Ideally, functions should be able to do three things:
>>>  1. return text (rendered to user) 
>>>  2. return nil (no response to user) 
>>>  3. return a jsonable object non-text, which would be added as a ```tools/function``` message to Chat Completion Request and then current agent would be called again.  **<-- This is missing from our implementation.**


> TODO: Example module.rb and passing into Team Runner


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

## State Map 
This is a powerful concept, which makes it easy for one agent to hand off to other agents or call functions based on a value returned by ChatGPT. This allows you to make a state machine or switchboard within a config, rather than in code.

Goals of this feature:
 * State machine/switchboard routes fully captured in configs.
   * _It is possible therefore to generate a complete state machine diagram, by examining only the state map sections of the configs within a project._
 * Value mapping can be to agent, function, or the special ignore function.
 * Functions and parameters exposed to ChatGPT can be expressive for prompt engineering.
 * Additional arguments, for example 'sentiment' will be passed to functions referenced in state map.


### State Map - Agent Forwarding

```state_map``` establishes a mapping between values that ChatGPT might return in a function call response and agents to call.

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
In this example, if the value of `request_type` is `get product info` then  `product_info` agent
will be created and message history will be handed over to it.

But, if the value of `request_type` is `file complaint` then  `customer_service` agent
will be created and message history will be handed over to it.

### State Map - Function Forwarding

```state_map``` also establishes a mapping between values that ChatGPT might return in a function call response and local functions to call.

Please note that a function referred to in a `state_map` must be defined in the agent's config in the `functions` section. And also note that, unlike other functions, this function will not be defined as local function in an Ability Module; However it will be present in Chat Completion Request and Response as defined in `functions` section of agent config.

```yaml
:state_map:
  :function_name: :set_request_type
  :argument_name: :request_type
  :values_map:
    :thanks and appreciation:
      :function: :thanks
    :terms of service:
      :function: :eula
```
In this example, if the value of `request_type` is `thanks and appreciation` then  `thanks` 
local function will be executed.

But, if the value of `request_type` is `terms of service` then  `eula` local function will be executed.

#### _Advanced function forwarding usage:_
Any additional arguments defined in the `function` section for `set_request_type`, for example 'sentiment', will be passed to the function being called. This allows the local function to make use of such values in its execution.

### State Map - Ignore

```state_map``` establishes a mapping between values that ChatGPT might return in a function call response and the special ignore function.

In our analysis, it was clear that a major use case of state map is to simply not respond to user request. For this reason, we have a special ignore function that will, simply log and respond to the user with nothing.

```yaml
:state_map:
  :function_name: :set_request_type
  :argument_name: :request_type
  :values_map:
    :spam:
      :ignore: :spam
    :other:
      :ignore: :other
```
In this example, if the value of `request_type` is `spam` then special ignore function will be called, with the `reason` argument of `spam`.

But, if the value of `request_type` is `other` then special ignore function will be called, with the `reason` argument of `other`.

### State Map - All Together Now

```state_map``` can, of course, be used to hand off to other agents, call local functions, or ignore.


```yaml
:state_map:
  :function_name: :set_request_type
  :argument_name: :request_type
  :values_map:
    :get product info:
      :agent: :product_info
    :file complaint:
      :agent: :customer_service
    :thanks and appreciation:
      :function: :thanks
    :terms of service:
      :function: :eula
    :spam:
      :ignore: :spam
    :other:
      :ignore: :other
```

#### Notes:
Only one function can be described in a config's `state_map`. 

**Avoid Infinite Loops!** It is possible to create an infinite loop with state maps; So don't do it.


