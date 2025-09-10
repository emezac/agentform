# frozen_string_literal: true

# Security concern for admin controllers
module AdminSecurity
  extend ActiveSupport::Concern

  included do
    # Rate limiting for admin operations
    before_action :check_admin_rate_limit
    
    # Enhanced CSRF protection for admin forms
    protect_from_forgery with: :exception, prepend: true
    
    # Input sanitization
    before_action :sanitize_params
    
    # Audit logging
    after_action :log_admin_action
  end

  private

  def check_admin_rate_limit
    return unless current_user

    cache_key = "admin_rate_limit:#{current_user.id}:#{request.remote_ip}"
    current_count = Rails.cache.read(cache_key) || 0
    
    # Allow 100 admin actions per hour per user/IP combination
    if current_count >= 100
      AuditLog.create!(
        user: current_user,
        event_type: 'admin_rate_limit_exceeded',
        details: {
          ip_address: request.remote_ip,
          user_agent: request.user_agent,
          controller: controller_name,
          action: action_name,
          current_count: current_count
        },
        ip_address: request.remote_ip
      )
      
      respond_to do |format|
        format.html do
          flash[:error] = 'Rate limit exceeded. Please wait before making more requests.'
          redirect_to admin_dashboard_path
        end
        format.json do
          render json: { error: 'Rate limit exceeded' }, status: :too_many_requests
        end
      end
      return
    end
    
    # Increment counter with 1 hour expiry
    Rails.cache.write(cache_key, current_count + 1, expires_in: 1.hour)
  end

  def sanitize_params
    return unless params.present?
    
    # Recursively sanitize all string parameters
    sanitize_hash(params)
  end

  def sanitize_hash(hash)
    hash.each do |key, value|
      case value
      when String
        # Remove potentially dangerous characters and scripts
        sanitized = sanitize_string(value)
        hash[key] = sanitized
      when Hash
        sanitize_hash(value)
      when Array
        value.each_with_index do |item, index|
          if item.is_a?(String)
            value[index] = sanitize_string(item)
          elsif item.is_a?(Hash)
            sanitize_hash(item)
          end
        end
      end
    end
  end

  def sanitize_string(str)
    return str if str.blank?
    
    # Remove null bytes
    str = str.delete("\0")
    
    # Remove or escape potentially dangerous HTML/JS
    str = ActionController::Base.helpers.strip_tags(str)
    
    # Remove SQL injection patterns (basic protection)
    dangerous_patterns = [
      /(\b(SELECT|INSERT|UPDATE|DELETE|DROP|CREATE|ALTER|EXEC|UNION)\b)/i,
      /(--|\/\*|\*\/|;)/,
      /(\bOR\b.*=.*\bOR\b)/i,
      /(\bAND\b.*=.*\bAND\b)/i
    ]
    
    dangerous_patterns.each do |pattern|
      if str.match?(pattern)
        AuditLog.create!(
          user: current_user,
          event_type: 'sql_injection_attempt',
          details: {
            original_input: str,
            pattern_matched: pattern.source,
            ip_address: request.remote_ip,
            user_agent: request.user_agent,
            controller: controller_name,
            action: action_name
          },
          ip_address: request.remote_ip
        )
        
        # Replace with safe placeholder
        str = str.gsub(pattern, '[FILTERED]')
      end
    end
    
    # Remove XSS patterns
    xss_patterns = [
      /<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/mi,
      /javascript:/i,
      /on\w+\s*=/i,
      /<iframe\b[^>]*>/i,
      /<object\b[^>]*>/i,
      /<embed\b[^>]*>/i
    ]
    
    xss_patterns.each do |pattern|
      if str.match?(pattern)
        AuditLog.create!(
          user: current_user,
          event_type: 'xss_attempt',
          details: {
            original_input: str,
            pattern_matched: pattern.source,
            ip_address: request.remote_ip,
            user_agent: request.user_agent,
            controller: controller_name,
            action: action_name
          },
          ip_address: request.remote_ip
        )
        
        str = str.gsub(pattern, '[FILTERED]')
      end
    end
    
    # Trim whitespace
    str.strip
  end

  def log_admin_action
    return unless current_user&.admin?
    return if action_name == 'index' && request.get? # Skip logging for simple index views
    
    # Don't log if response was an error (already logged elsewhere)
    return if response.status >= 400
    
    AuditLog.create!(
      user: current_user,
      event_type: 'admin_action',
      details: {
        controller: controller_name,
        action: action_name,
        method: request.method,
        path: request.path,
        params: filtered_params,
        user_agent: request.user_agent,
        response_status: response.status
      },
      ip_address: request.remote_ip
    )
  rescue => e
    # Don't let audit logging break the request
    Rails.logger.error "Failed to log admin action: #{e.message}"
  end

  def filtered_params
    # Remove sensitive parameters from logging
    params.except(:password, :password_confirmation, :current_password, 
                  :stripe_secret_key, :stripe_webhook_secret, :authenticity_token)
          .to_unsafe_h
  end

  # Strong parameter validation helpers
  def validate_admin_params(permitted_params, required_params = [])
    # Check for required parameters
    required_params.each do |param|
      unless permitted_params.key?(param) && permitted_params[param].present?
        raise ActionController::ParameterMissing.new(param)
      end
    end
    
    # Validate parameter types and formats
    permitted_params.each do |key, value|
      next if value.blank?
      
      case key.to_s
      when 'email'
        validate_email_format(value)
      when 'code'
        validate_discount_code_format(value)
      when 'discount_percentage'
        validate_percentage(value)
      when 'max_usage_count'
        validate_positive_integer(value)
      when 'role'
        validate_role(value)
      when 'subscription_tier'
        validate_subscription_tier(value)
      end
    end
    
    permitted_params
  end

  def validate_email_format(email)
    unless email.match?(URI::MailTo::EMAIL_REGEXP)
      raise ActionController::BadRequest.new("Invalid email format: #{email}")
    end
  end

  def validate_discount_code_format(code)
    # Discount codes should be alphanumeric, 3-20 characters
    unless code.match?(/\A[A-Z0-9]{3,20}\z/)
      raise ActionController::BadRequest.new("Invalid discount code format. Use 3-20 alphanumeric characters.")
    end
  end

  def validate_percentage(percentage)
    value = percentage.to_i
    unless value.between?(1, 99)
      raise ActionController::BadRequest.new("Discount percentage must be between 1 and 99")
    end
  end

  def validate_positive_integer(number)
    value = number.to_i
    unless value > 0
      raise ActionController::BadRequest.new("Value must be a positive integer")
    end
  end

  def validate_role(role)
    unless %w[user admin superadmin].include?(role)
      raise ActionController::BadRequest.new("Invalid role: #{role}")
    end
  end

  def validate_subscription_tier(tier)
    unless %w[basic premium].include?(tier)
      raise ActionController::BadRequest.new("Invalid subscription tier: #{tier}")
    end
  end
end