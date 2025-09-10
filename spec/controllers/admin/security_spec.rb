# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin Security', type: :request do
  let(:superadmin) { create(:user, role: 'superadmin') }
  let(:regular_user) { create(:user, role: 'user') }

  describe 'Admin::UsersController security' do
    before { sign_in superadmin }

    describe 'parameter validation' do
      it 'validates user creation parameters' do
        post '/admin/users', params: {
          user: {
            email: 'invalid-email',
            first_name: '',
            role: 'invalid_role'
          }
        }
        
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'sanitizes malicious input in user creation' do
        expect {
          post '/admin/users', params: {
            user: {
              email: 'test@example.com',
              first_name: '<script>alert("xss")</script>John',
              last_name: 'Doe',
              role: 'user'
            }
          }
        }.to change(AuditLog.where(event_type: 'xss_attempt'), :count).by(1)
      end

      it 'validates filter parameters' do
        get '/admin/users', params: {
          page: '-1',
          per_page: '1000',
          role: 'invalid_role'
        }
        
        # Should not crash, but should sanitize parameters
        expect(response).to have_http_status(:success)
      end

      it 'prevents SQL injection in search' do
        expect {
          get '/admin/users', params: {
            search: "'; DROP TABLE users; --"
          }
        }.to change(AuditLog.where(event_type: 'sql_injection_attempt'), :count).by(1)
      end
    end

    describe 'session security' do
      it 'detects IP address changes' do
        # Simulate initial request
        get '/admin/users'
        expect(response).to have_http_status(:success)
        
        # Simulate request from different IP
        allow_any_instance_of(ActionDispatch::Request).to receive(:remote_ip).and_return('192.168.1.100')
        
        expect {
          get '/admin/users'
        }.to change(AuditLog.where(event_type: 'suspicious_admin_activity'), :count).by(1)
        
        expect(response).to redirect_to(new_user_session_path)
      end

      it 'enforces session timeout' do
        # Set session to expired
        session = ActionDispatch::Request::Session.new(ActionDispatch::Session::CookieStore.new(nil, {}), {})
        session[:admin_last_activity] = 3.hours.ago.to_i
        allow_any_instance_of(ActionController::Base).to receive(:session).and_return(session)
        
        get '/admin/users'
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'Admin::DiscountCodesController security' do
    before { sign_in superadmin }

    describe 'parameter validation' do
      it 'validates discount code creation parameters' do
        post '/admin/discount_codes', params: {
          discount_code: {
            code: 'invalid code!',
            discount_percentage: '150'
          }
        }
        
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'validates expiration date' do
        post '/admin/discount_codes', params: {
          discount_code: {
            code: 'VALID123',
            discount_percentage: '20',
            expires_at: 1.day.ago.to_s
          }
        }
        
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'sanitizes malicious input in discount code creation' do
        expect {
          post '/admin/discount_codes', params: {
            discount_code: {
              code: '<script>alert("xss")</script>',
              discount_percentage: '20'
            }
          }
        }.to change(AuditLog.where(event_type: 'xss_attempt'), :count).by(1)
      end
    end
  end

  describe 'Rate limiting' do
    before { sign_in superadmin }

    it 'enforces rate limits on admin actions' do
      # Set rate limit to exceeded
      cache_key = "admin_rate_limit:#{superadmin.id}:127.0.0.1"
      Rails.cache.write(cache_key, 100, expires_in: 1.hour)
      
      get '/admin/users'
      expect(response).to have_http_status(:too_many_requests)
    end

    it 'logs rate limit violations' do
      cache_key = "admin_rate_limit:#{superadmin.id}:127.0.0.1"
      Rails.cache.write(cache_key, 100, expires_in: 1.hour)
      
      expect {
        get '/admin/users'
      }.to change(AuditLog.where(event_type: 'admin_rate_limit_exceeded'), :count).by(1)
    end
  end

  describe 'Authorization' do
    it 'blocks non-superadmin users from admin routes' do
      sign_in regular_user
      
      expect {
        get '/admin/users'
      }.to change(AuditLog, :count).by(1)
      
      expect(response).to redirect_to(root_path)
      
      audit_log = AuditLog.last
      expect(audit_log.details).to include('user_id' => regular_user.id)
    end

    it 'blocks unauthenticated users from admin routes' do
      get '/admin/users'
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe 'CSRF protection' do
    before { sign_in superadmin }

    it 'requires CSRF token for POST requests' do
      post '/admin/users', params: {
        user: {
          email: 'test@example.com',
          first_name: 'John',
          last_name: 'Doe',
          role: 'user'
        }
      }, headers: { 'X-CSRF-Token' => '' }
      
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'logs CSRF failures' do
      expect {
        post '/admin/users', params: {
          user: {
            email: 'test@example.com',
            first_name: 'John',
            last_name: 'Doe',
            role: 'user'
          }
        }, headers: { 'X-CSRF-Token' => 'invalid' }
      }.to change(AuditLog.where(event_type: 'csrf_failure'), :count).by(1)
    end
  end

  describe 'Input sanitization edge cases' do
    before { sign_in superadmin }

    it 'handles null bytes' do
      post '/admin/users', params: {
        user: {
          email: "test@example.com\0malicious",
          first_name: 'John',
          last_name: 'Doe',
          role: 'user'
        }
      }
      
      # Should not crash and should remove null bytes
      expect(response).to have_http_status(:success)
    end

    it 'handles deeply nested malicious content' do
      post '/admin/users', params: {
        user: {
          email: 'test@example.com',
          first_name: 'John',
          last_name: 'Doe',
          role: 'user',
          nested: {
            deep: {
              content: '<script>alert("deep")</script>'
            }
          }
        }
      }
      
      expect(response).to have_http_status(:success)
    end

    it 'handles array parameters with malicious content' do
      post '/admin/users', params: {
        user: {
          email: 'test@example.com',
          first_name: 'John',
          last_name: 'Doe',
          role: 'user'
        },
        tags: ['<script>alert("array")</script>', 'normal_tag']
      }
      
      expect(response).to have_http_status(:success)
    end
  end
end