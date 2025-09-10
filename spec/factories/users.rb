# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    password { "SecurePassword123!" }
    password_confirmation { password }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    role { :user }
    subscription_tier { 'basic' }
    confirmed_at { Time.current }
    
    # User role traits
    trait :admin do
      role { :admin }
    end
    
    trait :premium do
      subscription_tier { 'premium' }
      monthly_ai_limit { 100.0 }
    end
    
    trait :freemium do
      subscription_tier { 'freemium' }
      monthly_ai_limit { 10.0 }
    end

    trait :trialing_user do
      subscription_tier { 'basic' }
      subscription_status { 'trialing' }
      trial_ends_at { TrialConfig.trial_period_days.days.from_now }
      created_at { Time.current }
    end

    trait :stripe_configured do
      stripe_enabled { true }
      stripe_publishable_key { 'pk_test_123456789' }
      stripe_secret_key { 'sk_test_123456789' }
    end

    trait :with_stripe do
      stripe_customer_id { 'cus_test123456789' }
      stripe_enabled { true }
      stripe_publishable_key { 'pk_test_123456789' }
      stripe_secret_key { 'sk_test_123456789' }
    end

    trait :with_stripe_configuration do
      stripe_enabled { true }
      stripe_publishable_key { 'pk_test_123456789' }
      stripe_secret_key { 'sk_test_123456789' }
      stripe_customer_id { 'cus_test123456789' }
    end
    
    # User state traits
    trait :unconfirmed do
      confirmed_at { nil }
    end
    
    trait :with_forms do
      after(:create) do |user|
        create_list(:form, 3, user: user)
      end
    end
    
    trait :with_api_tokens do
      after(:create) do |user|
        create_list(:api_token, 2, user: user)
      end
    end
    
    # Callback to ensure valid email format
    before(:create) do |user|
      user.email = user.email.downcase
    end
  end
end