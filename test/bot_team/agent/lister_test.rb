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
        Agent::Lister.new(temperature: 0.2).tap do |c|
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
      Agent::Lister.new(
        list_prompt:
          "You are a chef who knows many recipies and when the user tells you something they want to make, " \
          "you give them the ingredient list",
        item_function: proc do |ingredient:, amount: nil|
          @ingredients[ingredient] = amount
        end
      )
    end

    it 'can list cookie ingredients' do
      @ingredients = {}
      recipie_maker.run(messages: [{ role: 'user', content: "Cookies" }])
      _(@ingredients.keys.map(&:downcase)).must_include('butter')
      _(@ingredients.keys.map(&:downcase)).must_include('salt')
    end
  end

  describe 'when listing Marx Brothers' do
    let(:marx_brothers) do
      Agent::Lister.new(
        list_prompt: "You are a Marx Brothers fan who is listing the brothers",
        descriptions: { name: "The first name of a Marx Brother" }
      )
    end

    it 'states the list of attributes from descriptions' do
      marx_brothers.run("Give me the first names of the Marx Brothers")
      _(marx_brothers.system_directives).must_include(' - "name": The first name of a Marx Brother')
    end

    it 'can list the Marx Brothers' do
      @brothers = marx_brothers.run("Give me the first names of the Marx Brothers")

      assert_operator(@brothers.count, :>=, 4)
      _(@brothers.map { |b| b[:name] }).must_include('Groucho')
      _(@brothers.map { |b| b[:name] }).must_include('Chico')
      _(@brothers.map { |b| b[:name] }).must_include('Harpo')
      _(@brothers.map { |b| b[:name] }).must_include('Zeppo')
    end
  end

  describe 'multiple_choices' do
    it 'raises error when requesting multiple choices but doesnt specify handling' do
      lister = Agent::Lister.new(num_choices: 2)
      _(proc { lister.run("List some colors that go with green") }).must_raise
    end

    it 'will unify the result when multiple_choices = concat' do
      lister = Agent::Lister.new(
        num_choices: 2,
        multiple_choices: :concat,
        descriptions: { color: 'Lower case common name of a color' }
      )
      result = lister.run("Give me exactly three different varieties of blue")
      _(result.count).must_equal(6)
    end

    it 'will return results separately when multiple_choices = separate' do
      lister = Agent::Lister.new(
        num_choices: 2,
        multiple_choices: :separate,
        descriptions: { color: 'Lower case common name of a color' }
      )
      result = lister.run("Give me exactly three different varieties of blue")
      _(result.count).must_equal(2)
      _(result[0].count).must_equal(3)
      _(result[1].count).must_equal(3)
    end

    it 'will dedupe results when multiple_choices = dedupe' do
      lister = Agent::Lister.new(
        num_choices: 2,
        multiple_choices: :dedupe,
        descriptions: { color: 'Lower case common name of a color' }
      )
      result = lister.run("Give me exactly three different varieties of blue")

      assert_operator(result.count, :<, 6)
      assert_operator(result.count, :>, 3)
    end
  end
end
