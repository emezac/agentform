# Premium AI Templates for Lead Qualification Agent
# These templates will be available to premium users only

puts "Creating premium AI templates..."

# Lead Qualification Agent Template
lead_qualification_template = FormTemplate.find_or_create_by!(name: "Intelligent Lead Qualification Agent", category: "lead_qualification") do |template|
  template.description = "An AI-powered form that automatically qualifies leads based on their responses, company data, and engagement patterns."
  template.visibility = "featured"
  template.estimated_time_minutes = 3
  template.template_data = {
    "settings": {
      "one_question_per_page": true,
      "show_progress_bar": true,
      "allow_multiple_submissions": false,
      "require_login": false,
      "collect_email": true,
      "thank_you_message": "Thank you! Our team will reach out to qualified leads within 24 hours.",
      "redirect_url": nil
    },
    "ai_configuration": {
      "enabled": true,
      "features": ["response_analysis", "dynamic_questions", "sentiment_analysis", "lead_scoring"],
      "model": "gpt-4o-mini",
      "temperature": 0.7,
      "max_tokens": 1000,
      "confidence_threshold": 0.75
    },
    "questions": [
      {
        "title": "What's your work email?",
        "description": "We'll use this to enrich your company profile",
        "question_type": "email",
        "required": true,
        "ai_enhanced": true,
        "ai_config": {
          "enrichment": true,
          "company_lookup": true
        }
      },
      {
        "title": "What's your biggest challenge right now?",
        "description": "Be specific - this helps us understand your needs better",
        "question_type": "text_long",
        "required": true,
        "ai_enhanced": true,
        "ai_config": {
          "sentiment_analysis": true,
          "intent_detection": true,
          "urgency_scoring": true
        }
      },
      {
        "title": "How urgent is this challenge?",
        "description": "This helps us prioritize your request",
        "question_type": "single_choice",
        "required": true,
        "options": [
          "Critical - need solution within 1 week",
          "High - need solution within 1 month",
          "Medium - need solution within 3 months",
          "Low - just exploring options"
        ]
      },
      {
        "title": "What's your current monthly budget for this solution?",
        "description": "This helps us recommend the right plan",
        "question_type": "single_choice",
        "required": true,
        "options": [
          "Under $500",
          "$500 - $2,000",
          "$2,000 - $5,000",
          "$5,000 - $10,000",
          "Over $10,000"
        ]
      },
      {
        "title": "How many team members would use this solution?",
        "description": "This helps us understand your scale",
        "question_type": "single_choice",
        "required": true,
        "options": [
          "Just me",
          "2-5 people",
          "6-20 people",
          "21-100 people",
          "100+ people"
        ]
      },
      {
        "title": "What specific outcome are you hoping to achieve?",
        "description": "Examples: increase conversion rate, reduce churn, save time, etc.",
        "question_type": "text_long",
        "required": true,
        "ai_enhanced": true,
        "ai_config": {
          "outcome_extraction": true,
          "goal_classification": true
        }
      }
    ]
  }
  template.features = ["ai_enhanced", "lead_qualification", "sentiment_analysis", "dynamic_questions", "company_enrichment"]
end

# Customer Feedback Agent Template
feedback_template = FormTemplate.find_or_create_by!(name: "AI Customer Feedback Analyzer", category: "customer_feedback") do |template|
  template.description = "Transform customer feedback into actionable insights with AI-powered sentiment analysis and theme extraction."
  template.visibility = "featured"
  template.estimated_time_minutes = 2
  template.template_data = {
    "settings": {
      "one_question_per_page": false,
      "show_progress_bar": true,
      "allow_multiple_submissions": true,
      "require_login": false,
      "collect_email": false,
      "thank_you_message": "Thank you for your feedback! Your insights will help us improve.",
      "redirect_url": nil
    },
    "ai_configuration": {
      "enabled": true,
      "features": ["sentiment_analysis", "theme_extraction", "priority_scoring", "actionable_insights"],
      "model": "gpt-4o-mini",
      "temperature": 0.6,
      "max_tokens": 800,
      "confidence_threshold": 0.8
    },
    "questions": [
      {
        "title": "How satisfied are you with our service?",
        "description": "Please rate your overall experience",
        "question_type": "nps_score",
        "required": true,
        "ai_enhanced": true,
        "ai_config": {
          "sentiment_tracking": true,
          "detractor_alert": true
        }
      },
      {
        "title": "What's the main reason for your rating?",
        "description": "Please be specific - this helps us improve",
        "question_type": "text_long",
        "required": true,
        "ai_enhanced": true,
        "ai_config": {
          "sentiment_analysis": true,
          "theme_extraction": true,
          "priority_scoring": true,
          "actionable_insights": true
        }
      },
      {
        "title": "Which aspect of our service could be improved?",
        "description": "Select all that apply",
        "question_type": "multiple_choice",
        "required": false,
        "options": [
          "Customer Support",
          "Product Features",
          "Pricing",
          "User Experience",
          "Documentation",
          "Response Time",
          "Other"
        ]
      },
      {
        "title": "How likely are you to recommend us to others?",
        "description": "This helps us understand your loyalty",
        "question_type": "single_choice",
        "required": true,
        "options": [
          "Very likely",
          "Somewhat likely",
          "Neutral",
          "Somewhat unlikely",
          "Very unlikely"
        ]
      }
    ]
  }
  template.features = ["ai_enhanced", "feedback_analysis", "sentiment_analysis", "theme_extraction"]
end

# Sales Discovery Agent Template
discovery_template = FormTemplate.find_or_create_by!(name: "AI Sales Discovery Form", category: "lead_qualification") do |template|
  template.description = "AI-powered discovery form that identifies high-intent prospects and prepares personalized follow-up strategies."
  template.visibility = "featured"
  template.estimated_time_minutes = 4
  template.template_data = {
    "settings": {
      "one_question_per_page": true,
      "show_progress_bar": true,
      "allow_multiple_submissions": false,
      "require_login": false,
      "collect_email": true,
      "thank_you_message": "Thank you! Our sales team will review your information and reach out with a personalized strategy.",
      "redirect_url": nil
    },
    "ai_configuration": {
      "enabled": true,
      "features": ["prospect_scoring", "personalization", "follow_up_strategy", "competitor_analysis"],
      "model": "gpt-4o-mini",
      "temperature": 0.7,
      "max_tokens": 1200,
      "confidence_threshold": 0.75
    },
    "questions": [
      {
        "title": "What's your role in the decision-making process?",
        "description": "This helps us understand how to best support you",
        "question_type": "single_choice",
        "required": true,
        "options": [
          "I'm the final decision maker",
          "I'm part of the decision team",
          "I influence decisions",
          "I provide recommendations",
          "I'm researching for my team"
        ]
      },
      {
        "title": "What's your biggest pain point right now?",
        "description": "Be specific - this helps us tailor our approach",
        "question_type": "text_long",
        "required": true,
        "ai_enhanced": true,
        "ai_config": {
          "pain_point_extraction": true,
          "urgency_scoring": true,
          "solution_mapping": true
        }
      },
      {
        "title": "What solutions are you currently evaluating?",
        "description": "This helps us understand your evaluation process",
        "question_type": "text_long",
        "required": false,
        "ai_enhanced": true,
        "ai_config": {
          "competitor_analysis": true,
          "positioning_insights": true
        }
      },
      {
        "title": "What's your timeline for implementation?",
        "description": "This helps us prioritize and plan",
        "question_type": "single_choice",
        "required": true,
        "options": [
          "Within 30 days",
          "1-3 months",
          "3-6 months",
          "6+ months",
          "Just researching"
        ]
      },
      {
        "title": "What's your approximate budget range?",
        "description": "This helps us recommend the right solution",
        "question_type": "single_choice",
        "required": true,
        "options": [
          "Under $1,000/month",
          "$1,000-$5,000/month",
          "$5,000-$15,000/month",
          "$15,000-$50,000/month",
          "$50,000+/month"
        ]
      }
    ]
  }
  template.features = ["ai_enhanced", "sales_discovery", "prospect_scoring", "personalization"]
end

puts "✅ Created premium AI templates:"
puts "   - #{lead_qualification_template.name}"
puts "   - #{feedback_template.name}"
puts "   - #{discovery_template.name}"

puts "Premium templates setup complete! 🚀"