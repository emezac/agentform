# frozen_string_literal: true

class <%= class_name %>Agent < ApplicationAgent
  <% actions_list.each do |action| %>
  def <%= action %>(params = {})
    prompt("<%= action.to_s.humanize %> for <%= singular_name %>: 
      Context: 
      Parameters: #{params}
    ").generate_now
  end
  <% end %>
end