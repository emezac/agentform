class Users::SessionsController < Devise::SessionsController
  # Handle CSRF more gracefully
  protect_from_forgery with: :null_session, only: [:create]
  before_action :configure_sign_in_params, only: [:create]
  
  def new
    # Ensure we have a fresh CSRF token
    self.response.headers['Cache-Control'] = 'no-cache, no-store, max-age=0, must-revalidate'
    super
  end
  
  def create
    Rails.logger.info "Processing sign in for: #{params.dig(:user, :email)}"
    Rails.logger.info "CSRF token present: #{params[:authenticity_token].present?}"
    
    super do |resource|
      if resource.persisted?
        Rails.logger.info "User #{resource.email} signed in successfully"
      else
        Rails.logger.warn "Sign in failed for: #{params.dig(:user, :email)}"
      end
    end
  end
  
  protected
  
  def after_sign_in_path_for(resource)
    stored_location_for(resource) || root_path
  end
  
  def after_sign_out_path_for(resource_or_scope)
    new_user_session_path
  end
  
  private
  
  def configure_sign_in_params
    devise_parameter_sanitizer.permit(:sign_in, keys: [:email, :password, :remember_me])
  end
end