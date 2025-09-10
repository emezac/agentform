# frozen_string_literal: true

FactoryBot.define do
  factory :form_template do
    association :creator, factory: :user
    name { "Sample Form Template" }
    description { "A comprehensive template for collecting user feedback" }
    category { :customer_feedback }
    visibility { :template_public }
    usage_count { 0 }
    estimated_time_minutes { 5 }
    
    template_data do
      {
        'questions' => [
          {
            'title' => 'What is your name?',
            'description' => 'Please enter your full name',
            'question_type' => 'text_short',
            'required' => true,
            'configuration' => { 'max_length' => 100 },
            'ai_enhanced' => false,
            'conditional_enabled' => false
          },
          {
            'title' => 'How would you rate our service?',
            'description' => 'Rate from 1 to 5 stars',
            'question_type' => 'rating',
            'required' => true,
            'configuration' => { 'min_value' => 1, 'max_value' => 5 },
            'ai_enhanced' => true,
            'ai_config' => { 'generate_followup' => true },
            'conditional_enabled' => false
          }
        ],
        'settings' => {
          'multi_step' => false,
          'show_progress' => true,
          'allow_save_progress' => false,
          'integrations' => []
        },
        'ai_configuration' => {
          'enabled' => true,
          'analysis_level' => 'standard',
          'auto_followup' => true
        }
      }
    end
    
    features { ['text_short', 'rating', 'ai_enhanced'] }
    
    trait :private do
      visibility { :template_private }
    end
    
    trait :public do
      visibility { :template_public }
    end
    
    trait :featured do
      visibility { :featured }
      usage_count { 100 }
    end
    
    trait :lead_qualification do
      name { "Lead Qualification Template" }
      category { :lead_qualification }
      description { "Qualify leads with AI-powered questions" }
      
      template_data do
        {
          'questions' => [
            {
              'title' => 'What is your company name?',
              'question_type' => 'text_short',
              'required' => true,
              'configuration' => { 'max_length' => 200 }
            },
            {
              'title' => 'What is your annual revenue?',
              'question_type' => 'number',
              'required' => true,
              'configuration' => { 'min_value' => 0 },
              'ai_enhanced' => true,
              'ai_config' => { 'qualify_lead' => true }
            },
            {
              'title' => 'What is your role in the company?',
              'question_type' => 'single_choice',
              'required' => true,
              'configuration' => {
                'options' => ['CEO', 'CTO', 'Manager', 'Developer', 'Other']
              }
            }
          ],
          'settings' => {
            'multi_step' => true,
            'show_progress' => true,
            'integrations' => [
              { 'type' => 'salesforce', 'enabled' => true }
            ]
          },
          'ai_configuration' => {
            'enabled' => true,
            'analysis_level' => 'advanced',
            'lead_scoring' => true
          }
        }
      end
      
      features { ['text_short', 'number', 'single_choice', 'ai_enhanced', 'multi_step', 'integration_salesforce'] }
    end
    
    trait :complex do
      name { "Complex Survey Template" }
      estimated_time_minutes { 15 }
      
      template_data do
        {
          'questions' => [
            {
              'title' => 'Personal Information',
              'question_type' => 'text_short',
              'required' => true
            },
            {
              'title' => 'Rate multiple aspects',
              'question_type' => 'matrix',
              'required' => true,
              'configuration' => {
                'rows' => ['Quality', 'Speed', 'Support'],
                'columns' => ['Poor', 'Fair', 'Good', 'Excellent']
              }
            },
            {
              'title' => 'Upload supporting documents',
              'question_type' => 'file_upload',
              'required' => false,
              'configuration' => {
                'max_files' => 3,
                'allowed_types' => ['pdf', 'doc', 'docx']
              }
            },
            {
              'title' => 'Conditional follow-up',
              'question_type' => 'text_long',
              'required' => false,
              'conditional_enabled' => true,
              'conditional_logic' => {
                'conditions' => [
                  {
                    'question_id' => 1,
                    'operator' => 'contains',
                    'value' => 'poor'
                  }
                ]
              }
            }
          ],
          'settings' => {
            'multi_step' => true,
            'show_progress' => true,
            'allow_save_progress' => true,
            'integrations' => [
              { 'type' => 'webhook', 'url' => 'https://example.com/webhook' }
            ]
          }
        }
      end
      
      features { ['text_short', 'matrix', 'file_upload', 'text_long', 'conditional_logic', 'multi_step', 'validation'] }
    end
    
    trait :without_creator do
      creator { nil }
    end
    
    trait :ai_enhanced do
      template_data do
        {
          'questions' => [
            {
              'title' => 'AI Enhanced Question',
              'question_type' => 'text_short',
              'ai_enhanced' => true,
              'ai_config' => {
                'generate_followup' => true,
                'sentiment_analysis' => true,
                'auto_categorize' => true
              }
            }
          ],
          'ai_configuration' => {
            'enabled' => true,
            'analysis_level' => 'advanced',
            'auto_followup' => true,
            'sentiment_analysis' => true
          }
        }
      end
      
      features { ['ai_enhanced', 'ai_generate_followup', 'ai_sentiment_analysis', 'ai_auto_categorize'] }
    end

    trait :with_payment_questions do
      name { "Payment Form Template" }
      category { :event_registration }
      description { "Template with payment questions for event registration" }
      payment_enabled { true }
      required_features { ['stripe_payments', 'premium_subscription'] }
      setup_complexity { 'moderate' }
      
      template_data do
        {
          'questions' => [
            {
              'title' => 'Event Registration',
              'question_type' => 'text_short',
              'required' => true,
              'configuration' => { 'max_length' => 100 }
            },
            {
              'title' => 'Payment Information',
              'question_type' => 'payment',
              'required' => true,
              'configuration' => {
                'amount' => 5000, # $50.00 in cents
                'currency' => 'usd',
                'description' => 'Event registration fee'
              }
            },
            {
              'title' => 'Additional Services',
              'question_type' => 'payment',
              'required' => false,
              'configuration' => {
                'amount' => 2500, # $25.00 in cents
                'currency' => 'usd',
                'description' => 'Optional workshop access'
              }
            }
          ],
          'settings' => {
            'multi_step' => true,
            'show_progress' => true,
            'payment_enabled' => true
          }
        }
      end
      
      features { ['text_short', 'payment', 'multi_step'] }
    end
    
    trait :simple do
      name { "Simple Contact Form" }
      category { :contact }
      description { "Basic contact form without payment features" }
      payment_enabled { false }
      required_features { [] }
      setup_complexity { 'simple' }
      
      template_data do
        {
          'questions' => [
            {
              'title' => 'Your Name',
              'question_type' => 'text_short',
              'required' => true
            },
            {
              'title' => 'Your Email',
              'question_type' => 'email',
              'required' => true
            },
            {
              'title' => 'Message',
              'question_type' => 'text_long',
              'required' => true
            }
          ],
          'settings' => {
            'multi_step' => false,
            'show_progress' => false
          }
        }
      end
      
      features { ['text_short', 'email', 'text_long'] }
    end
    
    trait :complex_with_payments do
      name { "Complex Payment Survey" }
      category { :survey }
      description { "Complex survey with multiple payment options" }
      payment_enabled { true }
      required_features { ['stripe_payments', 'premium_subscription', 'recurring_payments'] }
      setup_complexity { 'complex' }
      
      # Note: This trait creates a template that would have >50 questions when analyzed
      # The actual questions would be created when a form is generated from this template
    end
  end
end