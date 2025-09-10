class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Pundit authorization
  include Pundit::Authorization
  
  # Payment validation error handling
  include PaymentErrorHandling

  # CSRF protection with custom handling
  protect_from_forgery with: :exception
  
  # Devise authentication
  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?
  after_action :set_current_user
  
  # Nueva verificación del estado del trial - only for trial expiration
  before_action :check_trial_status, unless: -> { controller_name == 'billings' || controller_name == 'sessions' || controller_name == 'registrations' }

  # Global rescue handlers
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from Pundit::NotAuthorizedError, with: :render_unauthorized
  rescue_from ActionController::ParameterMissing, with: :render_bad_request
  rescue_from ActiveRecord::RecordInvalid, with: :render_unprocessable_entity
  rescue_from ActionController::InvalidAuthenticityToken, with: :handle_csrf_failure

  # SuperAgent specific error handling (conditional on SuperAgent being loaded)
  if defined?(SuperAgent)
    rescue_from SuperAgent::WorkflowError, with: :render_workflow_error
    rescue_from SuperAgent::TaskError, with: :render_workflow_error
  end
  
  if defined?(SuperAgent::A2A)
    rescue_from SuperAgent::A2A::TimeoutError, with: :render_timeout_error
    rescue_from SuperAgent::A2A::NetworkError, with: :render_network_error
    rescue_from SuperAgent::A2A::AuthenticationError, with: :render_unauthorized
  end

  # Global callbacks
  after_action :verify_authorized, except: [:index, :show], unless: :skip_authorization?
  after_action :verify_policy_scoped, only: [:index], unless: :skip_authorization?

  protected

  # Devise parameter configuration
  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:first_name, :last_name])
    devise_parameter_sanitizer.permit(:account_update, keys: [:first_name, :last_name, :preferences, :ai_settings])
  end

  # Current user helper for Pundit
  def pundit_user
    current_user
  end

  # Skip authorization for certain controllers
  def skip_authorization?
    devise_controller? || 
    controller_name == 'home' ||
    controller_name == 'health' ||
    controller_name == 'landing' ||
    controller_name == 'billings' ||
    action_name == 'public_form'
  end

  # Skip policy scoping for controllers that don't need it
  def should_verify_policy_scoped?
    false # Temporarily disable policy scoping verification
  end

  # CSRF failure handler
  def handle_csrf_failure(exception = nil)
    log_error(exception) if exception
    
    # Log CSRF failure for security monitoring
    AuditLog.create!(
      user: current_user,
      event_type: 'csrf_failure',
      details: {
        path: request.path,
        method: request.method,
        user_agent: request.user_agent,
        referer: request.referer,
        controller: controller_name,
        action: action_name
      },
      ip_address: request.remote_ip
    )
    
    # If user is trying to sign in and CSRF fails, redirect to fresh login page
    if request.path == new_user_session_path || request.path == user_session_path
      reset_session
      flash[:alert] = "Your session has expired. Please sign in again."
      redirect_to new_user_session_path
      return
    end
    
    respond_to do |format|
      format.html do
        if user_signed_in?
          flash[:alert] = "Security verification failed. Please try again."
          redirect_back(fallback_location: root_path)
        else
          reset_session
          flash[:alert] = "Your session has expired. Please sign in again."
          redirect_to new_user_session_path
        end
      end
      format.json do
        render json: { 
          error: "Invalid security token",
          message: "Please refresh the page and try again"
        }, status: :unprocessable_entity
      end
    end
  end

  # Error handling methods
  def render_not_found(exception = nil)
    log_error(exception) if exception
    
    respond_to do |format|
      format.html { render 'errors/404', status: :not_found, layout: 'error' }
      format.json { render json: { error: 'Resource not found' }, status: :not_found }
      format.any { head :not_found }
    end
  end

  def render_unauthorized(exception = nil)
    log_error(exception) if exception
    
    respond_to do |format|
      format.html { 
        flash[:alert] = 'You are not authorized to perform this action.'
        redirect_back(fallback_location: root_path)
      }
      format.json { render json: { error: 'Unauthorized' }, status: :unauthorized }
      format.any { head :unauthorized }
    end
  end

  def render_bad_request(exception = nil)
    log_error(exception) if exception
    
    respond_to do |format|
      format.html { 
        flash[:alert] = 'Invalid request parameters.'
        redirect_back(fallback_location: root_path)
      }
      format.json { render json: { error: 'Bad request', details: exception&.message }, status: :bad_request }
      format.any { head :bad_request }
    end
  end

  def render_unprocessable_entity(exception = nil)
    log_error(exception) if exception
    
    respond_to do |format|
      format.html { 
        flash[:alert] = 'There was an error processing your request.'
        redirect_back(fallback_location: root_path)
      }
      format.json { 
        render json: { 
          error: 'Unprocessable entity', 
          details: exception&.record&.errors&.full_messages || exception&.message 
        }, status: :unprocessable_entity 
      }
      format.any { head :unprocessable_entity }
    end
  end

  def render_workflow_error(exception = nil)
    log_error(exception) if exception
    
    respond_to do |format|
      format.html { 
        flash[:alert] = 'There was an error processing your workflow. Please try again.'
        redirect_back(fallback_location: root_path)
      }
      format.json { 
        render json: { 
          error: 'Workflow error', 
          details: exception&.message,
          workflow_id: exception&.workflow_id
        }, status: :unprocessable_entity 
      }
      format.any { head :unprocessable_entity }
    end
  end

  def render_timeout_error(exception = nil)
    log_error(exception) if exception
    
    respond_to do |format|
      format.html { 
        flash[:alert] = 'The request timed out. Please try again.'
        redirect_back(fallback_location: root_path)
      }
      format.json { 
        render json: { 
          error: 'Request timeout', 
          details: 'The operation took too long to complete'
        }, status: :request_timeout 
      }
      format.any { head :request_timeout }
    end
  end

  def render_network_error(exception = nil)
    log_error(exception) if exception
    
    respond_to do |format|
      format.html { 
        flash[:alert] = 'There was a network error. Please check your connection and try again.'
        redirect_back(fallback_location: root_path)
      }
      format.json { 
        render json: { 
          error: 'Network error', 
          details: exception&.message || 'Unable to connect to external service'
        }, status: :service_unavailable 
      }
      format.any { head :service_unavailable }
    end
  end

  private

  # --- NUEVO MÉTODO DE VERIFICACIÓN ---
  def check_trial_status
    return unless user_signed_in?
    return if current_user.superadmin?
    
    # Allow basic and premium users regardless of trial status
    return if ['basic', 'premium'].include?(current_user.subscription_tier)
    
    # Only check trial expiration for non-premium users
    return unless current_user.trial_expires_at.present? && current_user.trial_expired?
    
    redirect_to billing_path, alert: "Tu prueba gratuita de 14 días ha terminado. Por favor, elige un plan para continuar."
  end

  # Centralized error logging
  def log_error(exception)
    Rails.logger.error "#{exception.class}: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n") if exception.backtrace
    
    # Report to Sentry if configured
    if defined?(Sentry)
      Sentry.capture_exception(exception, extra: {
        user_id: current_user&.id,
        controller: controller_name,
        action: action_name,
        params: params.except(:password, :password_confirmation, :current_password).to_unsafe_h
      })
    end
  end

  # Helper method to check if user is admin
  def require_admin!
    render_unauthorized unless current_user&.admin?
  end

  # Helper method to check if user is premium or admin
  def require_premium!
    render_unauthorized unless current_user&.premium? || current_user&.admin?
  end

  # Set current user and request context for tracking purposes - MOVED TO AFTER_ACTION
  def set_current_user
    # Only set Current if user is authenticated to avoid interfering with Devise
    if user_signed_in?
      Current.user = current_user
      Current.request_id = request.uuid
      Current.user_agent = request.user_agent
      Current.ip_address = request.remote_ip
    end
  rescue => e
    # Log error but don't let it break the request
    Rails.logger.error "Error setting current user: #{e.message}"
  end
end