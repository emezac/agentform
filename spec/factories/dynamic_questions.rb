# frozen_string_literal: true

FactoryBot.define do
  factory :dynamic_question do
    association :form_response
    association :generated_from_question, factory: :form_question
    question_type { 'text_short' }
    title { 'Dynamic Question Title' }
    description { 'This is a dynamically generated question' }
    
    configuration do
      {
        'placeholder' => 'Enter your answer...',
        'max_length' => 500
      }
    end
    
    generation_context do
      {
        'trigger_answer' => 'Previous answer that triggered this question',
        'context_data' => { 'user_segment' => 'high_value' }
      }
    end
    
    generation_prompt { 'Generate a follow-up question based on the user\'s previous response' }
    generation_model { 'gpt-4' }
    
    trait :answered do
      answer_data do
        {
          'value' => 'Dynamic answer',
          'processed_at' => Time.current.iso8601
        }
      end
      response_time_ms { 15000 }
    end
    
    trait :with_high_confidence do
      ai_confidence { 0.95 }
    end
    
    trait :with_low_confidence do
      ai_confidence { 0.45 }
    end
    
    trait :text_long do
      question_type { 'text_long' }
      configuration do
        {
          'placeholder' => 'Please provide detailed information...',
          'max_length' => 2000,
          'rows' => 5
        }
      end
    end
    
    trait :multiple_choice do
      question_type { 'multiple_choice' }
      configuration do
        {
          'options' => ['Option A', 'Option B', 'Option C'],
          'allow_multiple' => true
        }
      end
    end
  end
end