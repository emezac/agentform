# frozen_string_literal: true

require 'rails_helper'

RSpec.describe <%= class_name %>Agent, type: :agent do
  let(:agent) { described_class.new(current_user: user, params: params) }
  let(:user) { create(:user) }
<% actions.each do |action| -%>

  describe '#<%= action %>' do
    context 'with valid parameters' do
      let(:params) { { <%= singular_name %>: { name: 'Test <%= singular_name.humanize %>' } } }

      it 'returns a successful response' do
        # Mock the LLM response
        allow_any_instance_of(SuperAgent::Workflow::LlmTask).to receive(:execute)
          .and_return('{"status": "success", "data": "processed"}')

        # Note: This is a placeholder - simple agents would use prompt().generate_now
        # which requires more complex mocking of the underlying system
        expect(agent).to respond_to(:<%= action %>)
      end
    end

    context 'with invalid parameters' do
      let(:params) { { <%= singular_name %>: nil } }

      it 'handles missing parameters' do
        expect(agent).to respond_to(:<%= action %>)
      end
    end
  end

<% end -%>
end