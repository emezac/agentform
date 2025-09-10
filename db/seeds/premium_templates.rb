# Create premium AI templates

puts "Creating premium AI templates..."

# Lead Qualification Agent Template
FormTemplate.find_or_create_by!(name: "Intelligent Lead Qualification Agent", category: "lead_qualification") do |template|
  template.description = "An AI-powered form that automatically qualifies leads based on their responses, company data, and engagement patterns."
  template.visibility = "featured"
  template.estimated_time_minutes = 3
  template.template_data = {
    "settings" => {
      "one_question_per_page" => true,
      "show_progress_bar" => true,
      "allow_multiple_submissions" => false,
      "require_login" => false,
      "collect_email" => true,
      "thank_you_message" => "Thank you! Our team will reach out to qualified leads within 24 hours.",
      "redirect_url" => nil
    },
    "ai_configuration" => {
      "enabled" => true,
      "features" => ["response_analysis", "dynamic_questions", "sentiment_analysis", "lead_scoring"],
      "model" => "gpt-4o-mini",
      "temperature" => 0.7,
      "max_tokens" => 1000,
      "confidence_threshold" => 0.75
    },
    "questions" => [
      {
        "title" => "What's your work email?",
        "description" => "We'll use this to enrich your company profile",
        "question_type" => "email",
        "required" => true,
        "ai_enhanced" => true,
        "ai_config" => {
          "enrichment" => true,
          "company_lookup" => true
        }
      },
      {
        "title" => "What's your biggest challenge right now?",
        "description" => "Be specific - this helps us understand your needs better",
        "question_type" => "text_long",
        "required" => true,
        "ai_enhanced" => true,
        "ai_config" => {
          "sentiment_analysis" => true,
          "intent_detection" => true,
          "urgency_scoring" => true
        }
      },
      {
        "title" => "How urgent is this challenge?",
        "description" => "This helps us prioritize your request",
        "question_type" => "single_choice",
        "required" => true,
        "options" => [
          "Critical - need solution within 1 week",
          "High - need solution within 1 month",
          "Medium - need solution within 3 months",
          "Low - just exploring options"
        ]
      },
      {
        "title" => "What's your current monthly budget for this solution?",
        "description" => "This helps us recommend the right plan",
        "question_type" => "single_choice",
        "required" => true,
        "options" => [
          "Under $500",
          "$500 - $2,000",
          "$2,000 - $5,000",
          "$5,000 - $10,000",
          "Over $10,000"
        ]
      }
    ]
  }
  template.features = ["ai_enhanced", "lead_qualification", "sentiment_analysis", "dynamic_questions", "company_enrichment"]
end

puts "✅ Created premium AI templates for Step 0 completion!"