# frozen_string_literal: true

# Lead Qualification Templates for Premium Users

puts "Creating lead qualification templates..."

# Template 1: AI-Powered Lead Qualification Agent
FormTemplate.create!(
  name: "AI-Powered Lead Qualification Agent",
  description: "Intelligent form that automatically qualifies leads using AI analysis. Analyzes company data, sentiment, and intent to score prospects.",
  category: "lead_qualification",
  visibility: "featured",
  estimated_time_minutes: 8,
  features: [
    "ai_enhanced",
    "response_analysis",
    "sentiment_analysis",
    "dynamic_questions",
    "lead_scoring",
    "company_enrichment",
    "follow_up_automation"
  ],
  template_data: {
    "settings" => {
      "one_question_per_page" => false,
      "show_progress_bar" => true,
      "allow_multiple_submissions" => false,
      "collect_email" => true,
      "require_login" => false,
      "thank_you_message" => "Thank you! We've analyzed your responses and will contact you shortly with personalized recommendations.",
      "redirect_url" => nil,
      "custom_branding" => true
    },
    "ai_configuration" => {
      "features" => ["response_analysis", "sentiment_analysis", "dynamic_questions", "lead_scoring"],
      "model" => "gpt-4o-mini",
      "temperature" => 0.7,
      "max_tokens" => 500,
      "confidence_threshold" => 0.75,
      "enable_company_enrichment" => true,
      "enable_follow_up_questions" => true,
      "lead_scoring_criteria" => {
        "company_size_weight" => 0.3,
        "sentiment_weight" => 0.2,
        "urgency_weight" => 0.25,
        "budget_match_weight" => 0.15,
        "decision_maker_weight" => 0.1
      }
    },
    "questions" => [
      {
        "title" => "What's your work email address?",
        "description" => "We'll use this to provide personalized recommendations and connect you with our team.",
        "question_type" => "email",
        "required" => true,
        "configuration" => {
          "placeholder" => "john@company.com",
          "validation" => {
            "type" => "email",
            "message" => "Please enter a valid work email address"
          }
        },
        "ai_enhanced" => true,
        "ai_config" => {
          "enrich_company_data" => true,
          "extract_domain_info" => true,
          "check_company_size" => true
        }
      },
      {
        "title" => "What's your biggest challenge right now?",
        "description" => "Tell us about the main problem you're trying to solve. The more detail you provide, the better we can help.",
        "question_type" => "text_long",
        "required" => true,
        "configuration" => {
          "placeholder" => "We're struggling with...",
          "min_length" => 20,
          "max_length" => 500
        },
        "ai_enhanced" => true,
        "ai_config" => {
          "analyze_sentiment" => true,
          "extract_keywords" => true,
          "identify_urgency" => true,
          "categorize_challenge" => true,
          "suggest_followup" => true
        }
      },
      {
        "title" => "What's your role in the decision-making process?",
        "description" => "This helps us understand how to best support you through the evaluation process.",
        "question_type" => "single_choice",
        "required" => true,
        "configuration" => {
          "options" => [
            "I'm the final decision maker",
            "I'm part of the decision-making team",
            "I recommend solutions to my team",
            "I research options for my team",
            "I'm just exploring options"
          ]
        },
        "ai_enhanced" => true,
        "ai_config" => {
          "score_decision_maker" => true,
          "weight_in_qualification" => 0.15
        }
      },
      {
        "title" => "What's your timeline for implementing a solution?",
        "description" => "Understanding your timeline helps us prioritize your needs appropriately.",
        "question_type" => "single_choice",
        "required" => true,
        "configuration" => {
          "options" => [
            "Immediately (within 1 week)",
            "Soon (within 1 month)",
            "This quarter",
            "Next quarter",
            "Just exploring - no specific timeline"
          ]
        },
        "ai_enhanced" => true,
        "ai_config" => {
          "score_urgency" => true,
          "weight_in_qualification" => 0.25
        }
      },
      {
        "title" => "What's your approximate budget range?",
        "description" => "This helps us recommend the most appropriate solution for your needs.",
        "question_type" => "single_choice",
        "required" => false,
        "configuration" => {
          "options" => [
            "Under $1,000",
            "$1,000 - $5,000",
            "$5,000 - $15,000",
            "$15,000 - $50,000",
            "$50,000+",
            "I need help determining the budget"
          ]
        },
        "ai_enhanced" => true,
        "ai_config" => {
          "score_budget_match" => true,
          "weight_in_qualification" => 0.15
        }
      },
      {
        "title" => "How did you hear about us?",
        "question_type" => "single_choice",
        "required" => false,
        "configuration" => {
          "options" => [
            "Google search",
            "Social media",
            "Referral from colleague/friend",
            "Industry publication",
            "Conference/event",
            "Other"
          ]
        }
      }
    ]
  }
)

# Template 2: Sales Discovery Agent
FormTemplate.create!(
  name: "Sales Discovery Agent",
  description: "Advanced sales qualification form that uses AI to identify buying signals, budget availability, and decision processes. Perfect for B2B sales teams.",
  category: "lead_qualification",
  visibility: "featured",
  estimated_time_minutes: 12,
  features: [
    "ai_enhanced",
    "response_analysis",
    "sentiment_analysis",
    "dynamic_questions",
    "lead_scoring",
    "company_enrichment",
    "competitor_analysis",
    "budget_discovery"
  ],
  template_data: {
    "settings" => {
      "one_question_per_page" => true,
      "show_progress_bar" => true,
      "allow_multiple_submissions" => false,
      "collect_email" => true,
      "require_login" => false,
      "thank_you_message" => "Thank you! Our team will analyze your responses and reach out with a personalized consultation within 24 hours.",
      "redirect_url" => nil
    },
    "ai_configuration" => {
      "features" => ["response_analysis", "sentiment_analysis", "dynamic_questions", "lead_scoring"],
      "model" => "gpt-4o-mini",
      "temperature" => 0.6,
      "max_tokens" => 750,
      "confidence_threshold" => 0.8,
      "enable_competitor_detection" => true,
      "enable_budget_discovery" => true,
      "lead_scoring_criteria" => {
        "company_size_weight" => 0.25,
        "budget_indicators_weight" => 0.3,
        "decision_authority_weight" => 0.2,
        "timeline_urgency_weight" => 0.15,
        "competitor_presence_weight" => 0.1
      },
      "qualification_threshold" => 75
    },
    "questions" => [
      {
        "title" => "What's your company name?",
        "description" => "We'll research your company to provide tailored recommendations.",
        "question_type" => "text_short",
        "required" => true,
        "configuration" => {
          "placeholder" => "Acme Corporation"
        },
        "ai_enhanced" => true,
        "ai_config" => {
          "enrich_company_data" => true,
          "extract_company_info" => true,
          "estimate_company_size" => true,
          "identify_industry" => true
        }
      },
      {
        "title" => "What's your role and team size?",
        "description" => "Understanding your position helps us assess decision-making authority and team structure.",
        "question_type" => "text_long",
        "required" => true,
        "configuration" => {
          "placeholder" => "I'm the Head of Marketing managing a team of 8 people...",
          "min_length" => 25,
          "max_length" => 300
        },
        "ai_enhanced" => true,
        "ai_config" => {
          "extract_role_info" => true,
          "estimate_team_size" => true,
          "assess_decision_making_authority" => true
        }
      },
      {
        "title" => "What solutions are you currently using?",
        "description" => "Tell us about your current setup and any tools you're evaluating alongside us.",
        "question_type" => "text_long",
        "required" => true,
        "configuration" => {
          "placeholder" => "We currently use... and are evaluating...",
          "min_length" => 30,
          "max_length" => 400
        },
        "ai_enhanced" => true,
        "ai_config" => {
          "identify_competitors" => true,
          "assess_switching_costs" => true,
          "evaluate_solution_maturity" => true,
          "detect_pain_points" => true
        }
      },
      {
        "title" => "What's driving the need for change?",
        "description" => "What specific challenges or opportunities are prompting you to look for a new solution?",
        "question_type" => "text_long",
        "required" => true,
        "configuration" => {
          "placeholder" => "We're looking for a solution because...",
          "min_length" => 40,
          "max_length" => 500
        },
        "ai_enhanced" => true,
        "ai_config" => {
          "analyze_pain_points" => true,
          "assess_urgency" => true,
          "identify_success_criteria" => true,
          "suggest_followup_questions" => true
        }
      },
      {
        "title" => "What's your decision-making process?",
        "description" => "Who else is involved in evaluating and approving this solution?",
        "question_type" => "multiple_choice",
        "required" => true,
        "configuration" => {
          "options" => [
            "I'm the sole decision maker",
            "I recommend, but need team approval",
            "I recommend, but need executive approval",
            "Team consensus required",
            "Executive approval required",
            "Procurement process involved",
            "Still determining the process"
          ]
        },
        "ai_enhanced" => true,
        "ai_config" => {
          "assess_sales_cycle_length" => true,
          "identify_stakeholders" => true,
          "estimate_decision_complexity" => true
        }
      },
      {
        "title" => "What's your timeline and budget expectations?",
        "description" => "Understanding your timeline and budget helps us prepare the right proposal.",
        "question_type" => "text_long",
        "required" => true,
        "configuration" => {
          "placeholder" => "We need to implement within 3 months and our budget range is...",
          "min_length" => 20,
          "max_length" => 300
        },
        "ai_enhanced" => true,
        "ai_config" => {
          "extract_budget_indicators" => true,
          "assess_timeline_urgency" => true,
          "identify_budget_constraints" => true
        }
      }
    ]
  }
)

puts "✅ Lead qualification templates created successfully!"
puts "   - AI-Powered Lead Qualification Agent"
puts "   - Sales Discovery Agent"
puts "   - Both templates are available for premium users only"