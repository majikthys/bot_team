# frozen_string_literal: true

class Agent::Lister < ChatGptAgent
  attr_reader :items

  attr_accessor :list_prompt

  def initialize(**args)
    # Set default agent configs before calling super so that
    # they can still be overridden by initialization args
    self.max_tokens = 300
    super
    @items = nil
    @result = nil
    @list_prompt = "The user will make a request and expect a list in response"
    @function = nil
    @parameters = {}
  end

  def item_function(method = nil, descriptions: {}, &block)
    raise "Must supply either a method or a block to item_function" unless method || block
    raise "Only one of method or block can be supplied to item_function" if method && block

    set_function_with_parameters(method || block, descriptions:)
  end

  def run(message = nil, **_args)
    raise "You must set item_function before running Lister" unless @function

    set_system_directives_from_options
    @result = super
    @result = @result.gsub(/^```.*/, '')
    JSON.parse(@result).each do |obj|
      obj = obj.map { |k, v| [k.to_sym, v] }.to_h
      @function.call(**obj)
    end
  end

  private

  def set_function_with_parameters(proc, descriptions:)
    @function = proc

    proc.parameters.each do |param|
      case param[0]
      when :keyreq
        setup_function_parameter(param[1], descriptions[param[1]], true)
      when :key
        setup_function_parameter(param[1], descriptions[param[1]], false)
      when :keyrest
        # do nothing
      when :req, :opt, :rest, :block
        raise ArgumentError, "Positional arguments, splats, and blocks are not allowed in item function, use keyword args and double splat only"
      end
    end
  end

  def setup_function_parameter(name, description = nil, required = false)
    @parameters[name.to_s] = {}
    @parameters[name.to_s][:required] = required
    @parameters[name.to_s][:description] = description
  end

  def set_system_directives_from_options
    @system_directives ||= ""
    @system_directives += <<~LIST_DIRECTIVES

      #{list_prompt}

      Your response will be a JSON array of objects. Here are the attributes the object in the array can have:

      #{@parameters.map { |name, attrs| " - \"#{name}\": #{attrs[:required] ? '(required)' : '(optional)'} #{attrs[:description]}" }.join("\n")}

      Please ensure that the JSON you return is parsable and that each contained object has every required attribute or this operation will fail.

      I'll repeat this because it's important: THE JSON YOU RETURN MUST PARSE. WHAT YOU RETURN WILL BE PUT DIRECTLY IN A JSON PARSER AND LOTS OF VERY CUTE CHILDREN WILL BE VERY SAD IF IT DOESN'T PARSE
    LIST_DIRECTIVES
  end
end
