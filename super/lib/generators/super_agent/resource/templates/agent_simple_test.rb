# frozen_string_literal: true

require 'test_helper'

class <%= class_name %>AgentTest < ActiveSupport::TestCase
  include SuperAgent::TestHelper

  let(:agent) { <%= class_name %>Agent.new(current_user: users(:one)) }
<% actions.each do |action| -%>

  test "#<%= action %> returns a response" do
    # Mock the LLM response for testing
    SuperAgent::LlmInterface.any_instance.stubs(:complete).returns("Test response")
    
    result = agent.<%= action %>(name: "test")
    assert result.completed?
    assert_equal "Test response", result.message
  end

<% end -%>
end
