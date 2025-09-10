# frozen_string_literal: true

FactoryBot.define do
  factory :audit_log do
    user { nil }
    event_type { 'admin_action' }
    details { { controller: 'test', action: 'index' } }
    ip_address { '127.0.0.1' }
    created_at { Time.current }

    trait :security_event do
      event_type { 'sql_injection_attempt' }
      details do
        {
          original_input: "'; DROP TABLE users; --",
          pattern_matched: 'SQL injection pattern',
          controller: 'admin/users',
          action: 'create'
        }
      end
    end

    trait :sql_injection_attempt do
      event_type { 'sql_injection_attempt' }
      details do
        {
          original_input: "'; DROP TABLE users; --",
          pattern_matched: 'SQL injection pattern',
          controller: 'admin/users',
          action: 'create'
        }
      end
    end

    trait :xss_attempt do
      event_type { 'xss_attempt' }
      details do
        {
          original_input: '<script>alert("xss")</script>',
          pattern_matched: 'XSS pattern',
          controller: 'admin/discount_codes',
          action: 'create'
        }
      end
    end

    trait :csrf_failure do
      event_type { 'csrf_failure' }
      details do
        {
          path: '/admin/users',
          method: 'POST',
          controller: 'admin/users',
          action: 'create'
        }
      end
    end

    trait :rate_limit_exceeded do
      event_type { 'admin_rate_limit_exceeded' }
      details do
        {
          current_count: 101,
          controller: 'admin/users',
          action: 'index'
        }
      end
    end

    trait :suspicious_admin_activity do
      event_type { 'suspicious_admin_activity' }
      details do
        {
          reason: 'ip_address_change',
          original_ip: '192.168.1.1',
          new_ip: '192.168.1.2'
        }
      end
    end

    trait :admin_session_expired do
      event_type { 'admin_session_expired' }
      details do
        {
          last_activity: 3.hours.ago,
          timeout_duration: 10800
        }
      end
    end

    trait :discount_code_created do
      event_type { 'discount_code_created' }
      details do
        {
          discount_code_id: SecureRandom.uuid,
          code: 'WELCOME20',
          discount_percentage: 20
        }
      end
    end

    trait :discount_code_updated do
      event_type { 'discount_code_updated' }
      details do
        {
          discount_code_id: SecureRandom.uuid,
          code: 'WELCOME20',
          changes: { discount_percentage: [20, 25] }
        }
      end
    end

    trait :user_created do
      event_type { 'user_created' }
      details do
        {
          user_id: SecureRandom.uuid,
          email: 'test@example.com',
          role: 'user'
        }
      end
    end

    trait :user_suspended do
      event_type { 'user_suspended' }
      details do
        {
          user_id: SecureRandom.uuid,
          email: 'test@example.com',
          reason: 'Violation of terms of service'
        }
      end
    end
  end
end