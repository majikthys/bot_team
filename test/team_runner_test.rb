# frozen_string_literal: true

require_relative '../lib/team_runner'
require 'test_helper'

describe TeamRunner do
  $LOAD_PATH << 'test/modules' unless $LOAD_PATH.include?('test/modules')

  subject do
    TeamRunner.new(
      agent_name: 'switchboard',
      messages: [{ user: 'set test value to 99' }],
      modules: [Switchboard, Leaf]
    ).tap do |runner|
      runner.config_root = 'test/config/test_agents/'
    end
  end

  it 'should run team of agents' do
    result = subject.call

    # Demonstrates that switchboard called leaf
    assert_equal 'OUTPUT FROM THE LEAF FUNCTION', result
    assert_equal 'OUTPUT FROM THE LEAF FUNCTION', subject.result
  end
end
