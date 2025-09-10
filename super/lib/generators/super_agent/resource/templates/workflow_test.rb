# frozen_string_literal: true

require 'test_helper'

class <%= class_name %>WorkflowTest < ActiveSupport::TestCase
  def setup
    @workflow = <%= class_name %>Workflow.new
  end

  def test_workflow_execution
    result = @workflow.execute(initial_input: { test: 'data' })
    assert result.success?
  end
end