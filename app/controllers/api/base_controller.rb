# frozen_string_literal: true

class Api::BaseController < ActionController::API
  # Include Pundit for authorization
  include Pundit::Authorization

  # API-specific callbacks
  before_action :authenticate_api_user!
  before_action :set_current_user
  before_action :set_default_format

  # Note: ActionController::API doesn't include CSRF protection by default

  protected

  # Token-based authentication
  def authenticate_api_user!
    token = extract_token_from_header
    
    if token.blank?
      render_authentication_required
      return
    end

    @current_api_token = ApiToken.authenticate(token)
    
    if @current_api_token.nil?
      render_invalid_token
      return
    end

    @current_user = @current_api_token.user
  end

  public

  # Current user for Pundit
  def current_user
    @current_user
  end

  # Current API token
  def current_api_token
    @current_api_token
  end

  protected

  # Pundit user
  def pundit_user
    current_user
  end

  # Check if current token has permission for resource and action
  def authorize_token!(resource, action)
    unless current_api_token.can_access?(resource, action)
      render_insufficient_permissions(resource, action)
      return false
    end
    true
  end

  # Set current user and request context
  def set_current_user
    Current.user = current_user
    Current.request_id = request.uuid
    Current.user_agent = request.user_agent
    Current.ip_address = request.remote_ip
    Current.api_token = current_api_token
  end

  # Set default format to JSON
  def set_default_format
    request.format = :json
  end

  # Extract token from Authorization header
  def extract_token_from_header
    auth_header = request.headers['Authorization']
    return nil if auth_header.blank?
    
    # Support both "Bearer token" and "token" formats
    if auth_header.start_with?('Bearer ')
      auth_header.sub('Bearer ', '')
    else
      auth_header
    end
  end

  # API Error Response Methods
  def render_authentication_required
    render json: {
      error: 'Authentication required',
      message: 'API token must be provided in Authorization header',
      code: 'AUTHENTICATION_REQUIRED'
    }, status: :unauthorized
  end

  def render_invalid_token
    render json: {
      error: 'Invalid token',
      message: 'The provided API token is invalid, expired, or revoked',
      code: 'INVALID_TOKEN'
    }, status: :unauthorized
  end

  def render_insufficient_permissions(resource, action)
    render json: {
      error: 'Insufficient permissions',
      message: "Token does not have permission to #{action} #{resource}",
      code: 'INSUFFICIENT_PERMISSIONS',
      required_permission: "#{resource}:#{action}"
    }, status: :forbidden
  end

  def render_not_found(exception = nil)
    log_error(exception) if exception
    
    render json: {
      error: 'Resource not found',
      message: 'The requested resource could not be found',
      code: 'NOT_FOUND'
    }, status: :not_found
  end

  def render_unauthorized(exception = nil)
    log_error(exception) if exception
    
    render json: {
      error: 'Unauthorized',
      message: 'You are not authorized to perform this action',
      code: 'UNAUTHORIZED'
    }, status: :unauthorized
  end

  def render_bad_request(exception = nil)
    log_error(exception) if exception
    
    render json: {
      error: 'Bad request',
      message: exception&.message || 'Invalid request parameters',
      code: 'BAD_REQUEST'
    }, status: :bad_request
  end

  def render_unprocessable_entity(exception = nil)
    log_error(exception) if exception
    
    errors = if exception&.record&.errors&.any?
               exception.record.errors.full_messages
             else
               [exception&.message || 'Validation failed']
             end

    render json: {
      error: 'Unprocessable entity',
      message: 'The request could not be processed due to validation errors',
      code: 'VALIDATION_ERROR',
      errors: errors
    }, status: :unprocessable_entity
  end

  def render_conflict(exception = nil)
    log_error(exception) if exception
    
    render json: {
      error: 'Conflict',
      message: 'The request conflicts with the current state of the resource',
      code: 'CONFLICT',
      details: exception&.message
    }, status: :conflict
  end

  def render_workflow_error(exception = nil)
    log_error(exception) if exception
    
    render json: {
      error: 'Workflow error',
      message: 'There was an error processing the workflow',
      code: 'WORKFLOW_ERROR',
      details: exception&.message,
      workflow_id: exception&.respond_to?(:workflow_id) ? exception.workflow_id : nil
    }, status: :unprocessable_entity
  end

  def render_timeout_error(exception = nil)
    log_error(exception) if exception
    
    render json: {
      error: 'Request timeout',
      message: 'The operation took too long to complete',
      code: 'TIMEOUT_ERROR'
    }, status: :request_timeout
  end

  def render_network_error(exception = nil)
    log_error(exception) if exception
    
    render json: {
      error: 'Network error',
      message: 'Unable to connect to external service',
      code: 'NETWORK_ERROR',
      details: exception&.message
    }, status: :service_unavailable
  end

  def render_internal_server_error(exception = nil)
    log_error(exception) if exception
    
    # Don't expose internal error details in production
    message = Rails.env.production? ? 'An internal error occurred' : exception&.message
    
    render json: {
      error: 'Internal server error',
      message: message,
      code: 'INTERNAL_ERROR'
    }, status: :internal_server_error
  end

  def render_rate_limit_exceeded
    render json: {
      error: 'Rate limit exceeded',
      message: 'Too many requests. Please try again later.',
      code: 'RATE_LIMIT_EXCEEDED'
    }, status: :too_many_requests
  end

  private

  # Centralized error logging for API
  def log_error(exception)
    Rails.logger.error "[API] #{exception.class}: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n") if exception.backtrace
    
    # Report to Sentry if configured
    if defined?(Sentry)
      Sentry.capture_exception(exception, extra: {
        user_id: current_user&.id,
        api_token_id: current_api_token&.id,
        controller: controller_name,
        action: action_name,
        params: params.except(:password, :password_confirmation, :current_password).to_unsafe_h,
        request_id: request.uuid,
        user_agent: request.user_agent,
        ip_address: request.remote_ip
      })
    end
  end

  # Helper methods for common API responses
  def render_success(data = {}, message: nil, status: :ok)
    response = { success: true }
    response[:message] = message if message
    response[:data] = data if data.present?
    
    render json: response, status: status
  end

  def render_created(data = {}, message: 'Resource created successfully')
    render_success(data, message: message, status: :created)
  end

  def render_updated(data = {}, message: 'Resource updated successfully')
    render_success(data, message: message, status: :ok)
  end

  def render_deleted(message: 'Resource deleted successfully')
    render_success({}, message: message, status: :ok)
  end

  # Pagination helpers
  def paginate_collection(collection, per_page: 25)
    page = params[:page]&.to_i || 1
    per_page = [params[:per_page]&.to_i || per_page, 100].min # Max 100 per page
    
    # Check if Kaminari is available
    if collection.respond_to?(:page)
      collection.page(page).per(per_page)
    else
      # Fallback to manual pagination
      offset = (page - 1) * per_page
      collection.limit(per_page).offset(offset)
    end
  end

  def pagination_meta(collection)
    if collection.respond_to?(:current_page)
      # Kaminari pagination
      {
        current_page: collection.current_page,
        per_page: collection.limit_value,
        total_pages: collection.total_pages,
        total_count: collection.total_count,
        has_next_page: collection.next_page.present?,
        has_prev_page: collection.prev_page.present?
      }
    else
      # Manual pagination fallback
      page = params[:page]&.to_i || 1
      per_page = [params[:per_page]&.to_i || 25, 100].min
      total_count = collection.is_a?(ActiveRecord::Relation) ? collection.count(:all) : collection.count
      total_pages = (total_count.to_f / per_page).ceil
      
      {
        current_page: page,
        per_page: per_page,
        total_pages: total_pages,
        total_count: total_count,
        has_next_page: page < total_pages,
        has_prev_page: page > 1
      }
    end
  end

  # Global rescue handlers for API (most specific first)
  
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

  # ActiveRecord specific errors
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :render_unprocessable_entity
  rescue_from ActiveRecord::RecordNotUnique, with: :render_conflict
  
  # Pundit authorization errors
  rescue_from Pundit::NotAuthorizedError, with: :render_unauthorized
  
  # Controller parameter errors
  rescue_from ActionController::ParameterMissing, with: :render_bad_request

  # Additional common errors
  rescue_from ArgumentError, with: :render_bad_request
  rescue_from JSON::ParserError, with: :render_bad_request
end