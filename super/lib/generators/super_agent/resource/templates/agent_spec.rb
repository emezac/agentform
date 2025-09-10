# frozen_string_literal: true

require 'rails_helper'

RSpec.describe <%= class_name %>Agent, type: :agent do
  let(:agent) { described_class.new }
  <% actions_list.each do |action| %>
  
  describe "#<%= action %>" do
    it "executes successfully" do
      result = agent.<%= action %>({})
      
      expect(result).to be_a(SuperAgent::WorkflowResult)
    end
  end
  <% end %>
end
EOF < /dev/null