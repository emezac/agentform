# frozen_string_literal: true

class <%= class_name %>Agent < ApplicationAgent
  def generate_response(context = {})
    prompt("Process: #{context}").generate_now
  end
end