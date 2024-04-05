# frozen_string_literal: true

require 'test_helper'

describe 'Agent::Lister' do
  def setup
    VCR.insert_cassette('agent_lister')
  end

  def teardown
    VCR.eject_cassette
  end

  describe 'when listing puppies' do
    def add_puppy(name:, color:)
      @puppies << { name:, color: }
    end

    it 'can find all the puppies in text' do
      @puppies = []
      descriptions = {
        name: "The name of the puppy you found in the text",
        color: "The color of the puppy you are reporting having found"
      }
      puppy_finder =
        Agent::Lister.new(config: {temperature: 0.2}).tap do |c|
          c.list_prompt = "You are a puppy finder that scans text and finds puppies."
          c.item_function(method(:add_puppy), descriptions:)
        end
      text = <<~TEXT
        In the kingdom of fluffypup, there was a doggy day care atop a hill overlooking the village.
        Everyday blue Jeremy would bring his sweet little brown dog Dingo to play with the other little guys.
        Dingo's favorite friend was young Rosa, a red retreiver the same age as Dingo.
        They loved to romp and play all day.
      TEXT
      puppy_finder.run(text)
      _(@puppies.count).must_equal(2)
      _(@puppies).must_include({ name: 'Dingo', color: 'brown' })
      _(@puppies).must_include({ name: 'Rosa', color: 'red' })
    end
  end

  describe 'when making cookies and sending a block' do
    let(:recipie_maker) do
      Agent::Lister.new.tap do |r|
        r.list_prompt = "You are a chef who knows many recipies and when the user tells you somwthing they want to make, you give them the ingredient list"
        r.item_function do |ingredient:, amount: nil|
          @ingredients[ingredient] = amount
        end
      end
    end

    it 'can list cookie ingredients' do
      @ingredients = {}
      recipie_maker.run(messages: [{ role: 'user', content: "Cookies" }])
      _(@ingredients.keys.map(&:downcase)).must_include('butter')
      _(@ingredients.keys.map(&:downcase)).must_include('salt')
    end
  end
end
