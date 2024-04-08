# frozen_string_literal: true

module Switchboard
  def thanks(sentiment:, classification_confidence:)
    "OUTPUT FROM THE SB THANKS FUNCTION SENTIMENT: #{sentiment} CONFIDENCE: #{classification_confidence}"
  end
end
