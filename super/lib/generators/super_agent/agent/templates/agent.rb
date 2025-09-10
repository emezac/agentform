# frozen_string_literal: true

class <%= class_name %>Agent < ApplicationAgent
  <% actions_list.each do |action| %>
  def <%= action %>(params = {})
    run_workflow(<%= class_name %>Workflow, initial_input: params)
  end
  <% end %>
end
EOF < /dev/null