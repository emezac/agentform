# frozen_string_literal: true

# Base service class for all business logic services in this application
class ApplicationService
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations
  
  attr_reader :result, :errors, :context
  
  def initialize(attributes = {})
    @context = {}
    @errors = ActiveModel::Errors.new(self)
    @result = nil
    
    super(attributes)
    
    setup_service if respond_to?(:setup_service, true)
  end
  
  # Main execution method - to be overridden by subclasses
  def call
    raise NotImplementedError, "Subclasses must implement the call method"
  end
  
  # Class method for convenient service execution
  def self.call(*args)
    service = new(*args)
    service.call
    service
  end
  
  # Check if service execution was successful
  def success?
    @errors.empty?
  end
  
  # Check if service execution failed
  def failure?
    !success?
  end
  
  # Add error to the service
  def add_error(attribute, message)
    @errors.add(attribute, message)
  end
  
  # Set the service result
  def set_result(result)
    @result = result
  end
  
  # Get context value
  def get_context(key)
    @context[key]
  end
  
  # Set context value
  def set_context(key, value)
    @context[key] = value
  end
  
  # Update context with hash
  def update_context(new_context)
    @context.merge!(new_context)
  end
  
  # Execute with error handling and logging
  def execute_safely
    Rails.logger.info "Executing service #{self.class.name}"
    
    begin
      validate_service_inputs if respond_to?(:validate_service_inputs, true)
      
      if valid?
        call
        log_success if success?
      else
        log_validation_errors
      end
    rescue StandardError => e
      handle_service_error(e)
    end
    
    self
  end
  
  # Execute another service from within this service
  def execute_service(service_class, *args)
    Rails.logger.debug "#{self.class.name} executing #{service_class.name}"
    
    service = service_class.call(*args)
    
    if service.failure?
      service.errors.each do |error|
        add_error(:service_execution, "#{service_class.name}: #{error.full_message}")
      end
    end
    
    service
  end
  
  # Execute with database transaction
  def execute_in_transaction
    ActiveRecord::Base.transaction do
      execute_safely
      
      if failure?
        Rails.logger.error "Service #{self.class.name} failed, rolling back transaction"
        raise ActiveRecord::Rollback
      end
    end
    
    self
  end
  
  # Format service response
  def response
    {
      success: success?,
      result: @result,
      errors: @errors.full_messages,
      service: self.class.name,
      timestamp: Time.current.iso8601
    }
  end
  
  # Get service status
  def status
    {
      service: self.class.name,
      success: success?,
      errors_count: @errors.count,
      has_result: !@result.nil?,
      context_keys: @context.keys
    }
  end
  
  protected
  
  # Handle service execution errors
  def handle_service_error(error)
    Rails.logger.error "Service #{self.class.name} failed: #{error.message}"
    Rails.logger.error error.backtrace.join("\n") if Rails.env.development?
    
    # Track error in Sentry if available
    if defined?(Sentry)
      Sentry.capture_exception(error, extra: {
        service: self.class.name,
        context: @context,
        attributes: attributes
      })
    end
    
    add_error(:execution, "Service execution failed: #{error.message}")
  end
  
  # Log successful execution
  def log_success
    Rails.logger.info "Service #{self.class.name} completed successfully"
  end
  
  # Log validation errors
  def log_validation_errors
    Rails.logger.warn "Service #{self.class.name} validation failed: #{@errors.full_messages.join(', ')}"
  end
  
  # Validate required attributes
  def validate_required_attributes(*required_attrs)
    required_attrs.each do |attr|
      if send(attr).blank?
        add_error(attr, "is required")
      end
    end
  end
  
  # Safe database operation
  def safe_db_operation
    ActiveRecord::Base.transaction do
      yield
    end
  rescue ActiveRecord::RecordInvalid => e
    add_error(:database, "Validation error: #{e.message}")
    nil
  rescue ActiveRecord::RecordNotFound => e
    add_error(:database, "Record not found: #{e.message}")
    nil
  rescue StandardError => e
    add_error(:database, "Database error: #{e.message}")
    nil
  end
  
  # Find record safely
  def find_record(model_class, id, error_attribute = :base)
    record = model_class.find_by(id: id)
    
    unless record
      add_error(error_attribute, "#{model_class.name} not found with id: #{id}")
    end
    
    record
  end
  
  # Check authorization
  def authorize_user(user, action, resource = nil)
    return true unless user # Skip if no user context
    
    # Basic authorization - extend with Pundit if needed
    case action.to_s
    when 'read'
      true
    when 'write', 'update', 'delete'
      user.role != 'user' || user_owns_resource?(user, resource)
    else
      false
    end
  end
  
  # Check if user owns resource
  def user_owns_resource?(user, resource)
    return false unless resource
    
    if resource.respond_to?(:user_id)
      resource.user_id == user.id
    elsif resource.respond_to?(:user)
      resource.user == user
    else
      false
    end
  end
  
  # Format error response
  def error_response(message, type = 'service_error')
    {
      success: false,
      error: true,
      error_message: message,
      error_type: type,
      service: self.class.name,
      timestamp: Time.current.iso8601
    }
  end
  
  # Format success response
  def success_response(data = {})
    {
      success: true,
      service: self.class.name,
      timestamp: Time.current.iso8601,
      data: data
    }
  end
end