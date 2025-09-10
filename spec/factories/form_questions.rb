# frozen_string_literal: true

FactoryBot.define do
  factory :form_question do
    association :form
    title { Faker::Lorem.question }
    description { Faker::Lorem.sentence }
    question_type { 'text_short' }
    required { false }
    sequence(:position) { |n| n }

    trait :required do
      required { true }
    end

    trait :multiple_choice do
      question_type { 'multiple_choice' }
      question_config do
        {
          'options' => [
            'Option 1',
            'Option 2', 
            'Option 3'
          ]
        }
      end
    end

    trait :single_choice do
      question_type { 'single_choice' }
      question_config do
        {
          'options' => [
            'Choice A',
            'Choice B',
            'Choice C'
          ]
        }
      end
    end

    trait :checkbox do
      question_type { 'checkbox' }
      question_config do
        {
          'options' => [
            'Option 1',
            'Option 2',
            'Option 3'
          ]
        }
      end
    end

    trait :email do
      question_type { 'email' }
      title { 'What is your email address?' }
    end

    trait :rating do
      question_type { 'rating' }
      title { 'How would you rate this?' }
      question_config do
        {
          'min_value' => 1,
          'max_value' => 5,
          'step' => 1,
          'labels' => { '1' => 'Poor', '5' => 'Excellent' }
        }
      end
    end

    trait :scale do
      question_type { 'scale' }
      title { 'Rate on a scale' }
      question_config do
        {
          'min_value' => 0,
          'max_value' => 10,
          'step' => 1
        }
      end
    end

    trait :nps_score do
      question_type { 'nps_score' }
      title { 'How likely are you to recommend us?' }
      question_config do
        {
          'min_value' => 0,
          'max_value' => 10,
          'step' => 1
        }
      end
    end

    trait :file_upload do
      question_type { 'file_upload' }
      title { 'Upload a file' }
      question_config do
        {
          'max_size_mb' => 10,
          'allowed_types' => ['pdf', 'doc', 'docx'],
          'multiple' => false
        }
      end
    end

    trait :image_upload do
      question_type { 'image_upload' }
      title { 'Upload an image' }
      question_config do
        {
          'max_size_mb' => 5,
          'allowed_types' => ['jpg', 'jpeg', 'png', 'gif'],
          'multiple' => false
        }
      end
    end

    trait :text_short do
      question_type { 'text_short' }
      question_config do
        {
          'min_length' => 0,
          'max_length' => 255,
          'placeholder' => 'Enter your answer'
        }
      end
    end

    trait :text_long do
      question_type { 'text_long' }
      question_config do
        {
          'min_length' => 0,
          'max_length' => 5000,
          'placeholder' => 'Enter your detailed answer'
        }
      end
    end

    trait :ai_enhanced do
      ai_enhanced { true }
      ai_config do
        {
          'features' => ['dynamic_followup', 'smart_validation'],
          'model' => 'gpt-4',
          'confidence_threshold' => 0.8
        }
      end
    end

    trait :with_conditional_logic do
      conditional_enabled { true }
      conditional_logic do
        {
          'rules' => [
            {
              'question_id' => 'previous_question',
              'operator' => 'equals',
              'value' => 'yes'
            }
          ]
        }
      end
    end

    trait :with_reference_id do
      sequence(:reference_id) { |n| "question_#{n}" }
    end

    trait :payment do
      question_type { 'payment' }
      title { 'Payment Information' }
      required { true }
      question_config do
        {
          'amount' => 50.00,
          'currency' => 'USD',
          'description' => 'Service payment',
          'payment_type' => 'one_time',
          'allow_custom_amount' => false
        }
      end
    end
  end
end