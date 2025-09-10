FactoryBot.define do
  factory :discount_code_usage do
    association :discount_code
    association :user
    subscription_id { "sub_#{SecureRandom.hex(8)}" }
    original_amount { 5000 } # $50.00 in cents
    discount_amount { 1000 } # $10.00 in cents
    final_amount { 4000 }    # $40.00 in cents
    used_at { Time.current }

    trait :high_value do
      original_amount { 10000 } # $100.00
      discount_amount { 2000 }  # $20.00
      final_amount { 8000 }     # $80.00
    end

    trait :low_value do
      original_amount { 2000 } # $20.00
      discount_amount { 200 }  # $2.00
      final_amount { 1800 }    # $18.00
    end

    trait :full_discount do
      original_amount { 5000 }
      discount_amount { 5000 }
      final_amount { 0 }
    end

    trait :recent do
      used_at { 1.hour.ago }
    end

    trait :old do
      used_at { 1.month.ago }
    end
  end
end