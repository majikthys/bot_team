# frozen_string_literal: true

require "test_helper"

describe ChatGptCost do
  describe "with bundled pricing file" do
    subject { ChatGptCost.new }

    it "looks up flex tier pricing" do
      price = subject.lookup(model: "gpt-5", tier: "flex", token_type: "input")
      _(price).must_equal 0.625

      cached_price = subject.lookup(model: "gpt-5", tier: "flex", token_type: "input_cached")
      _(cached_price).must_equal 0.0625

      output_price = subject.lookup(model: "gpt-5", tier: "flex", token_type: "output")
      _(output_price).must_equal 5.00
    end

    it "looks up standard tier pricing" do
      price = subject.lookup(model: "gpt-5", tier: "standard", token_type: "input")
      _(price).must_equal 1.25

      cached_price = subject.lookup(model: "gpt-5", tier: "standard", token_type: "input_cached")
      _(cached_price).must_equal 0.125

      output_price = subject.lookup(model: "gpt-5", tier: "standard", token_type: "output")
      _(output_price).must_equal 10.00
    end

    it "looks up priority tier pricing" do
      price = subject.lookup(model: "gpt-5", tier: "priority", token_type: "input")
      _(price).must_equal 2.50

      output_price = subject.lookup(model: "gpt-5", tier: "priority", token_type: "output")
      _(output_price).must_equal 20.00
    end

    it "maps default tier to standard" do
      price = subject.lookup(model: "gpt-5", tier: "default", token_type: "input")
      _(price).must_equal 1.25

      output_price = subject.lookup(model: "gpt-5", tier: "default", token_type: "output")
      _(output_price).must_equal 10.00
    end

    it "looks up pricing for different models" do
      mini_price = subject.lookup(model: "gpt-5-mini", tier: "flex", token_type: "input")
      _(mini_price).must_equal 0.125

      nano_price = subject.lookup(model: "gpt-5-nano", tier: "flex", token_type: "input")
      _(nano_price).must_equal 0.025

      gpt4_price = subject.lookup(model: "gpt-4.1", tier: "standard", token_type: "input")
      _(gpt4_price).must_equal 2.00
    end

    it "looks up batch tier pricing" do
      price = subject.lookup(model: "gpt-4o", tier: "batch", token_type: "input")
      _(price).must_equal 1.25

      output_price = subject.lookup(model: "gpt-4o", tier: "batch", token_type: "output")
      _(output_price).must_equal 5.00
    end

    it "returns nil for models without cached pricing" do
      cached_price = subject.lookup(model: "gpt-5-pro", tier: "batch", token_type: "input_cached")
      _(cached_price).must_be_nil
    end

    it "raises error for unknown model" do
      error = _ do
        subject.lookup(model: "unknown-model", tier: "flex", token_type: "input")
      end.must_raise ChatGptCost::PricingNotFoundError

      _(error.message).must_include "unknown-model"
      _(error.message).must_include "flex"
      _(error.message).must_include "input"
    end
  end

  describe "with custom pricing file" do
    it "loads from config/chat_gpt_cost.csv if it exists" do
      Dir.mkdir("config") unless Dir.exist?("config")

      custom_csv = "config/chat_gpt_cost.csv"
      File.write(custom_csv, <<~CSV)
        tier,model,input,input_cached,output
        custom,test-model,1.0,0.1,2.0
      CSV

      begin
        pricing = ChatGptCost.new
        price = pricing.lookup(model: "test-model", tier: "custom", token_type: "input")
        _(price).must_equal 1.0

        output_price = pricing.lookup(model: "test-model", tier: "custom", token_type: "output")
        _(output_price).must_equal 2.0
      ensure
        File.delete(custom_csv) if File.exist?(custom_csv)
        Dir.delete("config") if Dir.exist?("config") && Dir.empty?("config")
      end
    end
  end

  describe "error handling" do
    it "raises error when no pricing file found" do
      bundled_path = File.join(__dir__, "../../lib/bot_team/chat_gpt_cost.csv")
      temp_path = File.join(__dir__, "../../lib/bot_team/chat_gpt_cost.csv.bak")

      File.rename(bundled_path, temp_path) if File.exist?(bundled_path)

      begin
        error = _ do
          ChatGptCost.new
        end.must_raise ChatGptCost::PricingNotFoundError

        _(error.message).must_include "No pricing file found"
      ensure
        File.rename(temp_path, bundled_path) if File.exist?(temp_path)
      end
    end
  end
end
