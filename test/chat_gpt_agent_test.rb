require 'minitest/autorun'
require 'chat_completion/chat_gpt_agent'

describe ChatGptAgent do
  $LOAD_PATH << 'test/modules' unless $LOAD_PATH.include?('test/modules')

  def setup
    @subject = ChatGptAgent.new
  end

  it 'talks to api' do
    @subject.chat_gpt_request.functions=nil
    @subject.chat_gpt_request.add_user_message('please say hello')
    result = @subject.call

    assert_equal ChatGptResponse, result.class
    assert result.message.downcase.include?('hello'), "result should include 'hello'"
  end
end
