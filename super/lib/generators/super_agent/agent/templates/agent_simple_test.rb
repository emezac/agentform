# frozen_string_literal: true

require 'test_helper'

class <%= class_name %>AgentTest < ActiveSupport::TestCase
  include SuperAgent::TestHelper

  let(:agent) { <%= class_name %>Agent.new(current_user: users(:one)) }

  test "generate_response returns a response" do
    # Mock the LLM response for testing
    SuperAgent::LLMInterface.any_instance.stubs(:complete).returns("Test response")
    
    result = agent.generate_response({ name: "test" })
    assert_equal "Test response", result
  end
end