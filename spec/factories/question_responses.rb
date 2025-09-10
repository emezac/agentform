# frozen_string_literal: true

FactoryBot.define do
  factory :question_response do
    association :form_response
    association :form_question
    answer_text { 'Test answer' }
    answer_data { { 'value' => 'Test answer', 'processed_at' => Time.current.iso8601 } }
    time_spent_seconds { 30 }
    
    trait :text_answer do
      answer_text { 'This is a text answer' }
      answer_data { { 'value' => 'This is a text answer', 'processed_at' => Time.current.iso8601 } }
    end
    
    trait :email_answer do
      answer_text { 'test@example.com' }
      answer_data { { 'value' => 'test@example.com', 'processed_at' => Time.current.iso8601 } }
    end
    
    trait :multiple_choice_answer do
      answer_text { 'Option 1' }
      answer_data { { 'value' => ['Option 1', 'Option 2'], 'processed_at' => Time.current.iso8601 } }
    end
    
    trait :rating_answer do
      answer_text { '4' }
      answer_data { { 'value' => 4, 'processed_at' => Time.current.iso8601 } }
    end
    
    trait :skipped do
      skipped { true }
      answer_text { nil }
      answer_data { { 'skipped' => true } }
    end
    
    trait :with_ai_analysis do
      ai_analysis_results do
        {
          'sentiment' => 'positive',
          'confidence_score' => 0.9,
          'insights' => ['High quality response', 'Clear and detailed']
        }
      end
    end
    
    trait :fast_response do
      time_spent_seconds { 5 }
    end
    
    trait :slow_response do
      time_spent_seconds { 300 }
    end

    trait :with_time_data do
      time_spent_seconds { 30 }
      focus_time_seconds { 25 }
      blur_count { 2 }
      keystroke_count { 50 }
    end

    trait :yes_answer do
      answer_text { 'yes' }
      answer_data { { 'value' => 'yes', 'processed_at' => Time.current.iso8601 } }
    end

    trait :no_answer do
      answer_text { 'no' }
      answer_data { { 'value' => 'no', 'processed_at' => Time.current.iso8601 } }
    end
  end
end