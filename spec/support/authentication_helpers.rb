# frozen_string_literal: true

module AuthenticationHelpers
  # User Authentication Helpers
  
  def sign_in_user(user = nil)
    user ||= create(:user)
    sign_in user
    user
  end

  def sign_in_admin(user = nil)
    user ||= create(:user, :admin)
    sign_in user
    user
  end

  def sign_in_premium_user(user = nil)
    user ||= create(:user, :premium)
    sign_in user
    user
  end

  def sign_out_current_user
    sign_out :user if user_signed_in?
  end

  # API Authentication Helpers
  
  def api_headers(token = nil)
    token ||= create(:api_token)
    {
      'Authorization' => "Bearer #{token.token}",
      'Content-Type' => 'application/json',
      'Accept' => 'application/json'
    }
  end

  def api_headers_for_user(user)
    token = create(:api_token, user: user)
    api_headers(token)
  end

  def invalid_api_headers
    {
      'Authorization' => 'Bearer invalid_token_12345',
      'Content-Type' => 'application/json',
      'Accept' => 'application/json'
    }
  end

  def expired_api_headers
    token = create(:api_token, :expired)
    api_headers(token)
  end

  # Role-based Testing Helpers
  
  def as_user(role = :user, &block)
    user = create(:user, role: role)
    sign_in user
    yield(user) if block_given?
    user
  end

  def as_admin(&block)
    as_user(:admin, &block)
  end

  def as_premium_user(&block)
    as_user(:premium, &block)
  end

  def as_guest(&block)
    sign_out_current_user
    yield if block_given?
  end

  # Session Management Helpers
  
  def current_user_session
    controller.current_user if defined?(controller)
  end

  def simulate_user_session_timeout
    travel_to 2.hours.from_now do
      yield if block_given?
    end
  end

  def with_user_session(user, &block)
    sign_in user
    yield(user) if block_given?
  ensure
    sign_out user
  end

  # Token Management Helpers
  
  def create_api_token_for(user, **options)
    default_options = {
      name: 'Test Token',
      expires_at: 1.year.from_now
    }
    create(:api_token, default_options.merge(options).merge(user: user))
  end

  def create_readonly_token_for(user)
    create_api_token_for(user, 
      name: 'Readonly Token',
      permissions: ApiToken.readonly_permissions
    )
  end

  def create_full_access_token_for(user)
    create_api_token_for(user,
      name: 'Full Access Token', 
      permissions: ApiToken.full_permissions
    )
  end

  def create_forms_only_token_for(user)
    create_api_token_for(user,
      name: 'Forms Only Token',
      permissions: ApiToken.forms_only_permissions
    )
  end

  # Permission Testing Helpers
  
  def expect_authenticated_access
    expect(response).not_to have_http_status(:unauthorized)
    expect(response).not_to redirect_to(new_user_session_path)
  end

  def expect_unauthenticated_access
    expect(response).to have_http_status(:unauthorized)
  end

  def expect_admin_access_required
    expect(response).to have_http_status(:forbidden)
  end

  def expect_premium_access_required
    expect(response).to have_http_status(:forbidden)
  end

  # API Authentication Testing Helpers
  
  def expect_valid_api_authentication
    expect(response).not_to have_http_status(:unauthorized)
    expect(response).not_to have_http_status(:forbidden)
  end

  def expect_invalid_api_authentication
    expect(response).to have_http_status(:unauthorized)
    expect(json_response['error']).to include('authentication')
  end

  def expect_insufficient_api_permissions
    expect(response).to have_http_status(:forbidden)
    expect(json_response['error']).to include('permission')
  end

  # User State Helpers
  
  def create_confirmed_user(**attributes)
    create(:user, confirmed_at: Time.current, **attributes)
  end

  def create_unconfirmed_user(**attributes)
    create(:user, :unconfirmed, **attributes)
  end

  def create_user_with_forms(**attributes)
    create(:user, :with_forms, **attributes)
  end

  def create_user_with_api_tokens(**attributes)
    create(:user, :with_api_tokens, **attributes)
  end

  # Authentication Flow Testing Helpers
  
  def perform_login(email, password)
    post user_session_path, params: {
      user: {
        email: email,
        password: password
      }
    }
  end

  def perform_logout
    delete destroy_user_session_path
  end

  def perform_api_request(method, path, params = {}, headers = {})
    send(method, path, params: params, headers: headers)
  end

  def perform_authenticated_api_request(method, path, user, params = {})
    headers = api_headers_for_user(user)
    perform_api_request(method, path, params, headers)
  end

  # Test Data Cleanup Helpers
  
  def clear_user_sessions
    # Clear any cached user sessions
    Rails.cache.delete_matched("user_session_*")
  end

  def revoke_all_api_tokens
    ApiToken.update_all(active: false)
  end

  def cleanup_authentication_data
    clear_user_sessions
    revoke_all_api_tokens
  end

  # Shared Examples Support
  
  def it_requires_authentication(&block)
    context 'when user is not authenticated' do
      before { sign_out_current_user }
      
      it 'redirects to login page' do
        instance_eval(&block) if block_given?
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  def it_requires_admin_access(&block)
    context 'when user is not an admin' do
      before { sign_in_user }
      
      it 'denies access' do
        instance_eval(&block) if block_given?
        expect_admin_access_required
      end
    end
  end

  def it_requires_api_authentication(&block)
    context 'when API token is invalid' do
      it 'returns unauthorized' do
        @invalid_headers = invalid_api_headers
        instance_eval(&block) if block_given?
        expect_invalid_api_authentication
      end
    end
  end

  # Integration with RSpec metadata
  
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def with_authenticated_user(role = :user)
      before do
        @current_user = create(:user, role: role)
        sign_in @current_user
      end
    end

    def with_api_authentication(permissions = nil)
      before do
        @current_user = create(:user)
        @api_token = if permissions
          create(:api_token, user: @current_user, permissions: permissions)
        else
          create(:api_token, user: @current_user)
        end
        @api_headers = api_headers(@api_token)
      end
    end

    def without_authentication
      before do
        sign_out_current_user if respond_to?(:sign_out_current_user)
      end
    end
  end

  private

  def json_response
    JSON.parse(response.body) if response.body.present?
  rescue JSON::ParserError
    {}
  end
end