#!/usr/bin/env ruby
# frozen_string_literal: true

# Basic SuperAgent Workflow Example
# This example demonstrates a simple lead qualification workflow

require 'bundler/setup'
require 'super_agent'

# Define a simple workflow for lead qualification
class LeadQualificationWorkflow < SuperAgent::WorkflowDefinition
  define_task :validate_input, :direct_handler do |config|
    config.handler = ->(context) {
      lead = context.get(:lead)
      
      if lead[:email].nil? || lead[:email].empty?
        raise "Email is required"
      end
      
      { valid: true, email: lead[:email] }
    }
  end

  define_task :qualify_lead, :direct_handler do |config|
    config.handler = ->(context) {
      lead = context.get(:lead)
      score = 0
      
      # Simple scoring logic
      score += 50 if lead[:company]
      score += 30 if lead[:budget] > 1000
      score += 20 if lead[:timeline] == "immediate"
      
      {
        score: score,
        qualified: score >= 50,
        lead_id: lead[:id]
      }
    }
  end

  define_task :create_followup, :direct_handler do |config|
    config.handler = ->(context) {
      qualification = context.get(:qualify_lead)
      
      if qualification[:qualified]
        {
          action: "create_task",
          title: "Follow up with qualified lead #{qualification[:lead_id]}",
          priority: "high"
        }
      else
        {
          action: "send_nurture_email",
          lead_id: qualification[:lead_id],
          reason: "Score too low"
        }
      end
    }
  end
end

# Create a simple agent to use the workflow
class LeadAgent < SuperAgent::Base
  def qualify_lead(lead_data)
    context = SuperAgent::Workflow::Context.new(lead: lead_data)
    engine = SuperAgent::WorkflowEngine.new
    
    engine.execute(LeadQualificationWorkflow, context)
  end
end

# Example usage
if __FILE__ == $0
  puts "🚀 SuperAgent Lead Qualification Demo"
  puts "=" * 40

  # Test data
  test_leads = [
    { id: 1, email: "john@bigcorp.com", company: "BigCorp", budget: 5000, timeline: "immediate" },
    { id: 2, email: "jane@startup.io", budget: 500, timeline: "next_quarter" },
    { id: 3, email: "", company: "InvalidCo", budget: 10000 }
  ]

  agent = LeadAgent.new

  test_leads.each do |lead|
    puts "\n📊 Processing Lead ##{lead[:id]}: #{lead[:email]}"
    
    begin
      result = agent.qualify_lead(lead)
      
      if result.completed?
        qualification = result.output_for(:qualify_lead)
        puts "✅ Score: #{qualification[:score]} - Qualified: #{qualification[:qualified]}"
        
        followup = result.output_for(:create_followup)
        puts "📋 Next action: #{followup[:action]}"
      else
        puts "❌ Error: #{result.error_message}"
      end
    rescue => e
      puts "❌ Exception: #{e.message}"
    end
  end

  puts "\n🎉 Demo completed!"
end