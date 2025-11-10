# frozen_string_literal: true

require "csv"

class ChatGptCost
  class PricingNotFoundError < StandardError; end

  attr_reader :pricing_data

  def initialize
    @pricing_data = load_pricing_data
  end

  def lookup(model:, tier:, token_type:)
    normalized_tier = normalize_tier(tier)
    token_key = token_type.to_s

    model_pricing = pricing_data.dig(normalized_tier, model)

    unless model_pricing&.key?(token_key)
      raise PricingNotFoundError,
            "No pricing found for model: #{model}, tier: #{tier} (normalized: #{normalized_tier}), token_type: #{token_type}"
    end

    model_pricing[token_key]
  end

  private

  def auto_detect_pricing_file
    custom_path = "config/chat_gpt_cost.csv"
    bundled_path = File.join(__dir__, "chat_gpt_cost.csv")

    if File.exist?(custom_path)
      custom_path
    elsif File.exist?(bundled_path)
      bundled_path
    else
      raise PricingNotFoundError, "No pricing file found at #{custom_path} or #{bundled_path}"
    end
  end

  def normalize_tier(tier)
    tier.to_s == "default" ? "standard" : tier.to_s
  end

  def load_pricing_data
    data = {}

    CSV.foreach(auto_detect_pricing_file, headers: true) do |row|
      tier = row["tier"]
      model = row["model"]

      data[tier] ||= {}
      data[tier][model] ||= {}

      data[tier][model]["input"] = parse_price(row["input"])
      data[tier][model]["input_cached"] = parse_price(row["input_cached"])
      data[tier][model]["output"] = parse_price(row["output"])
    end

    data
  end

  def parse_price(value)
    return nil if value.nil? || value.strip.empty?

    value.to_f
  end
end
