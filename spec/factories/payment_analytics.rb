# frozen_string_literal: true

FactoryBot.define do
  factory :payment_analytic do
    association :user
    event_type { 'template_payment_interaction' }
    timestamp { Time.current }
    context { { template_id: '123', action: 'viewed' } }
    user_subscription_tier { user.subscription_tier }
    session_id { SecureRandom.hex(16) }
    user_agent { 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)' }
    ip_address { '192.168.1.0' }

    trait :template_interaction do
      event_type { 'template_payment_interaction' }
      context do
        {
          template_id: SecureRandom.uuid,
          template_name: 'Payment Form Template',
          payment_questions_count: 2,
          required_features: ['stripe_payments', 'premium_subscription'],
          setup_complexity: 'moderate'
        }
      end
    end

    trait :setup_started do
      event_type { 'payment_setup_started' }
      context do
        {
          required_features: ['stripe_payments', 'premium_subscription'],
          missing_requirements: ['stripe_configuration'],
          setup_actions_count: 2
        }
      end
    end

    trait :setup_completed do
      event_type { 'payment_setup_completed' }
      context do
        {
          required_features: ['stripe_payments', 'premium_subscription'],
          setup_completion_time: Time.current,
          features_validated: 2
        }
      end
    end

    trait :setup_abandoned do
      event_type { 'payment_setup_abandoned' }
      context do
        {
          form_id: SecureRandom.uuid,
          form_title: 'Test Payment Form',
          abandonment_point: 'form_editor',
          time_spent: 300,
          setup_progress: 50,
          missing_requirements: ['stripe_configuration']
        }
      end
    end

    trait :form_published do
      event_type { 'payment_form_published' }
      context do
        {
          form_id: SecureRandom.uuid,
          form_title: 'Published Payment Form',
          payment_questions_count: 1,
          published_at: Time.current
        }
      end
    end

    trait :validation_error do
      event_type { 'payment_validation_errors' }
      context do
        {
          form_id: SecureRandom.uuid,
          error_type: 'stripe_not_configured',
          error_title: 'Stripe Configuration Required',
          resolution_path: 'stripe_setup',
          priority: 'high'
        }
      end
    end

    # Traits for different user tiers
    trait :free_user do
      user_subscription_tier { 'free' }
      association :user, :free
    end

    trait :premium_user do
      user_subscription_tier { 'premium' }
      association :user, :premium
    end

    trait :admin_user do
      user_subscription_tier { 'premium' }
      association :user, :admin
    end

    # Traits for different time periods
    trait :recent do
      timestamp { 1.hour.ago }
    end

    trait :yesterday do
      timestamp { 1.day.ago }
    end

    trait :last_week do
      timestamp { 1.week.ago }
    end

    trait :last_month do
      timestamp { 1.month.ago }
    end

    # Traits for different error types
    trait :stripe_error do
      event_type { 'payment_validation_errors' }
      context do
        {
          error_type: 'stripe_not_configured',
          resolution_path: 'stripe_setup'
        }
      end
    end

    trait :premium_error do
      event_type { 'payment_validation_errors' }
      context do
        {
          error_type: 'premium_subscription_required',
          resolution_path: 'subscription_upgrade'
        }
      end
    end

    trait :multiple_requirements_error do
      event_type { 'payment_validation_errors' }
      context do
        {
          error_type: 'multiple_requirements_missing',
          resolution_path: 'complete_setup'
        }
      end
    end
  end
end