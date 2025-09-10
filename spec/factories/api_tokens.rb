# frozen_string_literal: true

FactoryBot.define do
  factory :api_token do
    association :user
    name { "Test API Token" }
    token { SecureRandom.hex(32) }
    expires_at { 1.year.from_now }
    last_used_at { nil }
    
    trait :expired do
      expires_at { 1.day.ago }
    end
    
    trait :recently_used do
      last_used_at { 1.hour.ago }
    end
    
    trait :with_permissions do
      permissions { %w[read write delete] }
    end
    
    # Override the token generation to ensure uniqueness
    after(:build) do |api_token|
      api_token.token = "test_token_#{SecureRandom.hex(16)}" if api_token.token.blank?
    end
  end
end