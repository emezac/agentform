FactoryBot.define do
  factory :discount_code do
    sequence(:code) { |n| "DISCOUNT#{n}" }
    discount_percentage { 20 }
    max_usage_count { 100 }
    current_usage_count { 0 }
    expires_at { 1.month.from_now }
    active { true }
    association :created_by, factory: :user

    trait :expired do
      expires_at { 1.day.ago }
    end

    trait :inactive do
      active { false }
    end

    trait :unlimited_usage do
      max_usage_count { nil }
    end

    trait :usage_limit_reached do
      max_usage_count { 10 }
      current_usage_count { 10 }
    end

    trait :high_discount do
      discount_percentage { 50 }
    end

    trait :low_discount do
      discount_percentage { 5 }
    end
  end
end