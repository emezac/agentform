# frozen_string_literal: true

require 'rails_helper'

RSpec.describe <%= class_name %>Workflow, type: :workflow do
  describe '#execute' do
    let(:workflow) { described_class.new }
    let(:input) { { test: 'data' } }
    
    it 'executes successfully' do
      result = workflow.execute(initial_input: input)
      expect(result).to be_success
    end
    
    # Add more specific tests based on your workflow logic
  end
end