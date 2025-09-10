# frozen_string_literal: true

FactoryBot.define do
  factory :form_response do
    association :form
    session_id { "session_#{SecureRandom.hex(16)}" }
    status { :in_progress }
    started_at { Time.current }
    ip_address { '127.0.0.1' }
    user_agent { 'Test User Agent' }
    
    trait :completed do
      status { :completed }
      completed_at { Time.current }
    end
    
    trait :abandoned do
      status { :abandoned }
      abandoned_at { Time.current }
      abandonment_reason { 'user_abandoned' }
    end
    
    trait :paused do
      status { :paused }
      paused_at { Time.current }
    end
    
    trait :with_utm_data do
      utm_data do
        {
          'utm_source' => 'google',
          'utm_medium' => 'cpc',
          'utm_campaign' => 'test_campaign'
        }
      end
    end
    
    trait :with_ai_analysis do
      ai_analysis do
        {
          'sentiment' => 'positive',
          'confidence_score' => 0.85,
          'summary' => 'Test AI analysis summary',
          'insights' => ['Test insight 1', 'Test insight 2']
        }
      end
    end
  end
end