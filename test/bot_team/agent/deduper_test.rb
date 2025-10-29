# frozen_string_literal: true

require "test_helper"

describe "Agent::Lister" do
  def setup
    VCR.insert_cassette("agent_deduper")
  end

  def teardown
    VCR.eject_cassette
  end

  describe "when looking at names" do
    let(:deduper) do
      Agent::Deduper.new(temperature: 0.2)
    end

    let(:names) do
      [
        { name: "Jim Morris" },
        { name: "Jeff McDaniels" },
        { name: "Charles Avery" },
        { name: "Jenn Jordan" },
        { name: "James Morris" },
        { name: "Jeffery Mcdaniels" }
      ]
    end

    it "can dedupe name variations w/o ids" do
      results = deduper.run(names)
      _(results.count).must_equal(4)
      _(results.map { |r| r[:originals].sort_by { |o| o[:name] } }.sort_by(&:to_s)).must_equal(
        [
          [ { name: "Charles Avery" } ],
          [ { name: "James Morris" }, { name: "Jim Morris" } ],
          [ { name: "Jeff McDaniels" }, { name: "Jeffery Mcdaniels" } ],
          [ { name: "Jenn Jordan" } ]
        ]
      )
    end
  end
end
