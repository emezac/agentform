# frozen_string_literal: true

namespace :test do
  desc "Create a test form for budget adaptation"
  task create_budget_form: :environment do
    puts "Creating test form for budget adaptation..."
    
    user = User.first
    unless user
      puts "No user found. Creating a test user..."
      user = User.create!(
        email: "test@example.com",
        password: "password123",
        name: "Test User"
      )
    end
    
    # Create form with AI enabled
    form = Form.create!(
      name: "Budget Adaptation Test Form",
      description: "Testing dynamic budget adaptation with AI",
      user: user,
      status: :published,
      ai_configuration: {
        "enabled" => true,
        "model" => "gpt-4o-mini",
        "features" => ["budget_adaptation"]
      }
    )
    
    # Create a budget-related question
    budget_question = FormQuestion.create!(
      form: form,
      title: "What is your budget for this project?",
      description: "Please indicate your budget in USD",
      question_type: "text_short",
      position: 1,
      required: true
    )
    
    # Create a follow-up question
    followup_question = FormQuestion.create!(
      form: form,
      title: "What functionality is most important to you?",
      description: "Describe the main feature you need",
      question_type: "text_long",
      position: 2,
      required: false
    )
    
    puts "✅ Test form created successfully!"
    puts "Name: #{form.name}"
    puts "Share token: #{form.share_token}"
    puts "URL: #{form.public_url}"
    puts ""
    puts "Form questions:"
    form.form_questions.each do |q|
      puts "  #{q.position}. #{q.title} (#{q.question_type})"
    end
    
    puts ""
    puts "To test the budget adaptation:"
    puts "1. Visit: #{form.public_url}"
    puts "2. Enter a low budget amount (e.g., $1000)"
    puts "3. The system will generate a dynamic follow-up question"
    puts ""
  end
end