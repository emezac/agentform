# frozen_string_literal: true

require 'rails_helper'

RSpec.describe <%= class_name %>Agent, type: :agent do
  let(:agent) { described_class.new(current_user: user, params: params) }
  let(:user) { create(:user) }
  let(:params) { { name: 'Test' } }

  describe '#generate_response' do
    context 'with valid parameters' do
      it 'returns a successful response' do
        # Mock the LLM response
        allow_any_instance_of(SuperAgent::Workflow::LlmTask).to receive(:execute)
          .and_return('{"status": "success", "data": "processed"}')

        expect(agent).to respond_to(:generate_response)
      end
    end

    context 'with invalid parameters' do
      it 'handles missing parameters' do
        expect(agent).to respond_to(:generate_response)
      end
    end
  end
end