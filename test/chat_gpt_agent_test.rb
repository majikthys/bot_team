require 'minitest/autorun'
require 'chat_completion/chat_gpt_agent'

describe ChatGptAgent do
  $LOAD_PATH << 'test/modules' unless $LOAD_PATH.include?('test/modules')

  def setup
    @subject = ChatGptAgent.new
  end

  it 'loads modules' do
    refute @subject.respond_to?(:change_state), "@subject should not respond to :change_state"
    @subject.load_module('Leaf')
    assert @subject.respond_to?(:change_state), "@subject should respond to :change_state"
  end

  it 'talks to api' do
    @subject.chat_gpt_request.functions=nil
    @subject.chat_gpt_request.add_user_message('please say hello')
    result = @subject.call

    assert_equal String, result.class
    assert result.downcase.include?('hello'), "result should include 'hello'"
  end
end
