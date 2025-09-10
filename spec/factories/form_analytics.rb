# frozen_string_literal: true

FactoryBot.define do
  factory :form_analytic do
    association :form
    date { Date.current }
    period_type { 'daily' }
    views_count { 100 }
    started_responses_count { 75 }
    completed_responses_count { 60 }
    abandoned_responses_count { 15 }
    avg_completion_time { 180 } # 3 minutes in seconds
    avg_time_per_question { 2500 } # 2.5 seconds in milliseconds
    
    trait :weekly do
      period_type { 'weekly' }
      date { Date.current.beginning_of_week }
      views_count { 700 }
      started_responses_count { 525 }
      completed_responses_count { 420 }
      abandoned_responses_count { 105 }
    end
    
    trait :monthly do
      period_type { 'monthly' }
      date { Date.current.beginning_of_month }
      views_count { 3000 }
      started_responses_count { 2250 }
      completed_responses_count { 1800 }
      abandoned_responses_count { 450 }
    end
    
    trait :high_performance do
      views_count { 1000 }
      started_responses_count { 900 }
      completed_responses_count { 850 }
      abandoned_responses_count { 50 }
      avg_completion_time { 120 } # 2 minutes - fast completion
      avg_time_per_question { 1500 } # 1.5 seconds - quick responses
    end
    
    trait :low_performance do
      views_count { 1000 }
      started_responses_count { 300 }
      completed_responses_count { 100 }
      abandoned_responses_count { 200 }
      avg_completion_time { 600 } # 10 minutes - slow completion
      avg_time_per_question { 8000 } # 8 seconds - slow responses
    end
    
    trait :no_completions do
      completed_responses_count { 0 }
      abandoned_responses_count { started_responses_count }
      avg_completion_time { 0 }
    end
    
    trait :perfect_conversion do
      started_responses_count { views_count }
      completed_responses_count { started_responses_count }
      abandoned_responses_count { 0 }
    end
    
    trait :yesterday do
      date { Date.yesterday }
    end
    
    trait :last_week do
      date { 1.week.ago.to_date }
    end
    
    trait :last_month do
      date { 1.month.ago.to_date }
    end
    
    trait :with_zero_views do
      views_count { 0 }
      started_responses_count { 0 }
      completed_responses_count { 0 }
      abandoned_responses_count { 0 }
      avg_completion_time { 0 }
      avg_time_per_question { 0 }
    end
    
    # Trait for testing trend calculations
    trait :improving_trend do
      # This would be used with a previous analytic that has lower performance
      views_count { 500 }
      started_responses_count { 400 }
      completed_responses_count { 350 }
      abandoned_responses_count { 50 }
      avg_completion_time { 150 }
    end
    
    trait :declining_trend do
      # This would be used with a previous analytic that has higher performance
      views_count { 200 }
      started_responses_count { 100 }
      completed_responses_count { 50 }
      abandoned_responses_count { 50 }
      avg_completion_time { 400 }
    end
  end
end