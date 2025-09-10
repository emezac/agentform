# frozen_string_literal: true

require 'rails_helper'

RSpec.describe <%= class_name %>Workflow, type: :workflow do
  let(:context) { SuperAgent::Workflow::Context.new(input: "test data") }
  let(:engine) { SuperAgent::WorkflowEngine.new }

  describe "execution" do
    it "successfully completes" do
      result = engine.execute(<%= class_name %>Workflow, context)
      
      expect(result).to be_completed
    end
  end
end
EOF < /dev/null