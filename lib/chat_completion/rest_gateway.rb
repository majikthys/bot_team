# frozen_string_literal: true

require 'httparty'

class RestGateway
  include HTTParty

  def api_key
    ENV['OPENAI_API_KEY']
  end

  def api_url
    'https://api.openai.com/v1/chat/completions'
  end

  def http_headers
    http_headers = {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{api_key}"
    }
  end

  def call(chat_completion_request)
    response = HTTParty.post(api_url, body: chat_completion_request.to_json, headers: http_headers, timeout: 45)
    raise response['error']['message'] unless response.code == 200

    ChatGptResponse.create_from_json(response)
  end
end
