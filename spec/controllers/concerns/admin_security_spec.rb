# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AdminSecurity, type: :controller do
  let(:superadmin) { create(:user, role: 'superadmin') }
  
  before do
    sign_in superadmin
  end

  describe 'rate limiting' do
    controller(Admin::UsersController) do
      # Use existing action
    end

    it 'allows normal request volume' do
      get :index
      expect(response).to have_http_status(:success)
    end

    it 'blocks excessive requests' do
      cache_key = "admin_rate_limit:#{superadmin.id}:127.0.0.1"
      Rails.cache.write(cache_key, 100, expires_in: 1.hour)
      
      get :index
      expect(response).to have_http_status(:too_many_requests)
    end

    it 'logs rate limit violations' do
      cache_key = "admin_rate_limit:#{superadmin.id}:127.0.0.1"
      Rails.cache.write(cache_key, 100, expires_in: 1.hour)
      
      expect {
        get :index
      }.to change(AuditLog, :count).by(1)
      
      audit_log = AuditLog.last
      expect(audit_log.event_type).to eq('admin_rate_limit_exceeded')
      expect(audit_log.user).to eq(superadmin)
    end
  end

  describe 'input sanitization' do
    controller(Admin::UsersController) do
      # Use existing create action
    end

    it 'logs XSS attempts in user creation' do
      expect {
        post :create, params: { 
          user: {
            email: 'test@example.com',
            first_name: '<script>alert("xss")</script>John',
            last_name: 'Doe',
            role: 'user'
          }
        }
      }.to change(AuditLog.where(event_type: 'xss_attempt'), :count).by(1)
      
      xss_log = AuditLog.where(event_type: 'xss_attempt').last
      expect(xss_log.user).to eq(superadmin)
      expect(xss_log.details['original_input']).to include('<script>')
    end

    it 'logs SQL injection attempts in search' do
      expect {
        get :index, params: { search: "'; DROP TABLE users; --" }
      }.to change(AuditLog.where(event_type: 'sql_injection_attempt'), :count).by(1)
      
      sql_log = AuditLog.where(event_type: 'sql_injection_attempt').last
      expect(sql_log.user).to eq(superadmin)
      expect(sql_log.details['original_input']).to include('DROP TABLE')
    end
  end

  describe 'parameter validation' do
    controller(Admin::UsersController) do
      # Use existing actions
    end

    it 'validates user creation with invalid email' do
      expect {
        post :create, params: { 
          user: {
            email: 'invalid-email',
            first_name: 'John',
            last_name: 'Doe',
            role: 'user'
          }
        }
      }.to raise_error(ActionController::BadRequest, /Invalid email format/)
    end

    it 'validates user creation with invalid role' do
      expect {
        post :create, params: { 
          user: {
            email: 'test@example.com',
            first_name: 'John',
            last_name: 'Doe',
            role: 'invalid_role'
          }
        }
      }.to raise_error(ActionController::BadRequest, /Invalid role/)
    end

    it 'accepts valid user creation parameters' do
      post :create, params: { 
        user: {
          email: 'test@example.com',
          first_name: 'John',
          last_name: 'Doe',
          role: 'user'
        }
      }
      
      expect(response).to have_http_status(:success)
    end
  end

  describe 'audit logging' do
    controller(Admin::UsersController) do
      # Use existing actions
    end

    it 'logs admin actions for non-index requests' do
      expect {
        post :create, params: { 
          user: {
            email: 'test@example.com',
            first_name: 'John',
            last_name: 'Doe',
            role: 'user'
          }
        }
      }.to change(AuditLog.where(event_type: 'admin_action'), :count).by(1)
      
      audit_log = AuditLog.where(event_type: 'admin_action').last
      expect(audit_log.user).to eq(superadmin)
      expect(audit_log.details['controller']).to eq('admin/users')
      expect(audit_log.details['action']).to eq('create')
    end

    it 'does not log index GET requests' do
      expect {
        get :index
      }.not_to change(AuditLog.where(event_type: 'admin_action'), :count)
    end

    it 'filters sensitive parameters from logs' do
      post :create, params: { 
        user: {
          email: 'test@example.com',
          first_name: 'John',
          last_name: 'Doe',
          role: 'user',
          password: 'secret123'
        }
      }
      
      audit_log = AuditLog.where(event_type: 'admin_action').last
      expect(audit_log.details['params']).not_to have_key('password')
      expect(audit_log.details['params']).to have_key('user')
    end
  end

  describe 'CSRF protection' do
    it 'is enabled for admin controllers' do
      expect(Admin::BaseController.forgery_protection_strategy).not_to be_nil
    end
  end
end