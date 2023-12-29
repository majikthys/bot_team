
module Switchboard
  def set_request_type(request_type:, sentiment:, classification_confidence:)
    puts "I set request type #{request_type} #{sentiment} #{classification_confidence}"
  end
end