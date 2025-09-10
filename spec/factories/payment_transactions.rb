FactoryBot.define do
  factory :payment_transaction do
    user { nil }
    form { nil }
    form_response { nil }
    stripe_payment_intent_id { "MyString" }
    amount { "9.99" }
    currency { "MyString" }
    status { "MyString" }
    payment_method { "MyString" }
    metadata { "" }
  end
end
