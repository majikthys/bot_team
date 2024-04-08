# frozen_string_literal: true

require 'test_helper'

describe 'Agent::Chooser' do
  def setup
    VCR.insert_cassette('agent_chooser')
  end

  def teardown
    VCR.eject_cassette
  end

  def giving_info
    @action = 'giving'
  end

  def requesting_info
    @action = 'requesting'
  end

  def unknown
    @action = 'unknown'
  end

  let(:give_or_request) do
    Agent::Chooser.new(
      temperature: 0.2,
      methods: {
        'giving' => method(:giving_info),
        'requesting' => method(:requesting_info),
        'unknown' => method(:unknown)
      },
      descriptions: {
        'giving' => 'User is giving some information',
        'requesting' => 'User is requesting some information',
        'unknown' => 'The input is incomprehensible or the user is neither requesting nor offering information'
      }
    )
  end

  it 'can classify a giving request' do
    give_or_request.run('My name is Bob')
    _(@action).must_equal('giving')
  end

  it 'can classify a requesting request' do
    give_or_request.run('Who is the president of the United States?')
    _(@action).must_equal('requesting')
  end

  it 'can classify an unknown request' do
    give_or_request.run('Shabazoo')
    _(@action).must_equal('unknown')
  end
end
