FactoryBot.define do
  factory :admin_notification do
    event_type { AdminNotification::EVENT_TYPES.values.sample }
    title { "Test notification" }
    message { "This is a test notification message" }
    user { association :user }
    metadata { {} }
    read_at { nil }
    priority { AdminNotification::PRIORITIES.values.sample }
    category { AdminNotification::CATEGORIES.values.sample }

    trait :read do
      read_at { 1.hour.ago }
    end

    trait :unread do
      read_at { nil }
    end

    trait :critical do
      priority { 'critical' }
    end

    trait :high_priority do
      priority { 'high' }
    end

    trait :user_registered do
      event_type { 'user_registered' }
      title { 'New user registered' }
      priority { 'normal' }
      category { 'user_activity' }
    end

    trait :trial_expired do
      event_type { 'trial_expired' }
      title { 'Trial expired' }
      priority { 'high' }
      category { 'billing' }
    end

    trait :payment_failed do
      event_type { 'payment_failed' }
      title { 'Payment failed' }
      priority { 'high' }
      category { 'billing' }
    end
  end
end
