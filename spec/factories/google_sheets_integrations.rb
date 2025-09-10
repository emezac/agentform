FactoryBot.define do
  factory :google_sheets_integration do
    association :form
    spreadsheet_id { "1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms" }
    sheet_name { "Responses" }
    auto_sync { false }
    active { true }
    field_mapping { {} }
    sync_count { 0 }

    trait :with_auto_sync do
      auto_sync { true }
    end

    trait :inactive do
      active { false }
    end

    trait :with_error do
      active { false }
      error_message { "API rate limit exceeded" }
    end

    trait :recently_synced do
      last_sync_at { 1.hour.ago }
      sync_count { 5 }
    end
  end
end