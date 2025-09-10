# frozen_string_literal: true

# Base agent class for all SuperAgent agents in this application
class ApplicationAgent
  # TODO: Include SuperAgent::AgentHelpers when SuperAgent gem is fully configured
  
  attr_reader :context, :logger
  
  def initialize(context = {})
    @context = context.is_a?(Hash) ? context : {}
    @logger = defined?(Rails) ? Rails.logger : Logger.new(STDOUT)
    @agent_id = SecureRandom.uuid
    
    # Initialize agent-specific context
    @context[:agent_id] = @agent_id
    @context[:agent_class] = self.class.name
    @context[:created_at] = defined?(Rails) ? Time.current : Time.now
    
    setup_agent if respond_to?(:setup_agent, true)
  end
  
  # Main execution method - to be overridden by subclasses
  def execute(input = {})
    raise NotImplementedError, "Subclasses must implement the execute method"
  end
  
  # Execute a workflow with error handling
  def execute_workflow(workflow_class, inputs = {})
    logger.info "Agent #{self.class.name} executing workflow #{workflow_class.name}"
    
    begin
      context = SuperAgent::Workflow::Context.new(inputs.merge(agent_context))
      engine = SuperAgent::WorkflowEngine.new
      result = engine.execute(workflow_class, context)
      
      log_workflow_result(workflow_class, result)
      result
    rescue StandardError => e
      logger.error "Workflow execution failed in #{self.class.name}: #{e.message}"
      handle_workflow_error(workflow_class, e)
    end
  end
  
  # Get agent context for workflows
  def agent_context
    {
      agent_id: @agent_id,
      agent_class: self.class.name,
      context: @context
    }
  end
  
  # Update agent context
  def update_context(new_context)
    @context.merge!(new_context)
  end
  
  # Get context value
  def get_context(key)
    @context[key]
  end
  
  # Set context value
  def set_context(key, value)
    @context[key] = value
  end
  
  # Check if agent can handle a specific task
  def can_handle?(task_type)
    supported_tasks.include?(task_type.to_s)
  end
  
  # Get list of supported tasks - to be overridden by subclasses
  def supported_tasks
    []
  end
  
  # Validate required context keys
  def validate_context(*required_keys)
    missing_keys = required_keys.select { |key| @context[key].nil? }
    
    if missing_keys.any?
      error_message = "Missing required context: #{missing_keys.join(', ')}"
      logger.error error_message
      raise ArgumentError, error_message
    end
    
    true
  end
  
  # Execute with timeout and retry logic
  def execute_with_retry(max_retries: 3, timeout: 30.seconds)
    retries = 0
    
    begin
      Timeout.timeout(timeout) do
        yield
      end
    rescue StandardError => e
      retries += 1
      
      if retries <= max_retries
        logger.warn "Agent execution failed (attempt #{retries}/#{max_retries}): #{e.message}"
        sleep(retries * 0.5) # Exponential backoff
        retry
      else
        logger.error "Agent execution failed after #{max_retries} retries: #{e.message}"
        raise e
      end
    end
  end
  
  # Format success response
  def success_response(data = {})
    {
      success: true,
      agent: self.class.name,
      agent_id: @agent_id,
      timestamp: (defined?(Rails) ? Time.current : Time.now).iso8601,
      data: data
    }
  end
  
  # Format error response
  def error_response(message, error_type = 'agent_error', data = {})
    {
      success: false,
      error: true,
      error_message: message,
      error_type: error_type,
      agent: self.class.name,
      agent_id: @agent_id,
      timestamp: (defined?(Rails) ? Time.current : Time.now).iso8601,
      data: data
    }
  end
  
  # Log agent activity
  def log_activity(action, details = {})
    logger.info "Agent #{self.class.name} (#{@agent_id}): #{action}"
    logger.debug "Details: #{details.inspect}" if details.any?
  end
  
  # Check if agent is in valid state
  def valid_state?
    @context.present? && @agent_id.present?
  end
  
  # Get agent status
  def status
    {
      agent_id: @agent_id,
      agent_class: self.class.name,
      created_at: @context[:created_at],
      context_keys: @context.keys,
      valid_state: valid_state?,
      supported_tasks: supported_tasks
    }
  end
  
  protected
  
  # Handle workflow execution errors
  def handle_workflow_error(workflow_class, error)
    logger.error "Workflow #{workflow_class.name} failed: #{error.message}"
    
    # Track error in Sentry if available
    if defined?(Sentry)
      Sentry.capture_exception(error, extra: {
        agent: self.class.name,
        agent_id: @agent_id,
        workflow: workflow_class.name,
        context: @context
      })
    end
    
    error_response(
      "Workflow execution failed: #{error.message}",
      'workflow_error',
      { workflow: workflow_class.name }
    )
  end
  
  # Log workflow execution results
  def log_workflow_result(workflow_class, result)
    if result.is_a?(Hash) && result[:error]
      logger.error "Workflow #{workflow_class.name} completed with error: #{result[:error_message]}"
    else
      logger.info "Workflow #{workflow_class.name} completed successfully"
    end
  end
  
  # Validate input parameters
  def validate_input(input, required_keys = [])
    return false unless input.is_a?(Hash)
    
    missing_keys = required_keys.select { |key| input[key].nil? }
    
    if missing_keys.any?
      logger.error "Missing required input keys: #{missing_keys.join(', ')}"
      return false
    end
    
    true
  end
  
  # Safe database operation execution
  def safe_db_operation
    ActiveRecord::Base.transaction do
      yield
    end
  rescue ActiveRecord::RecordInvalid => e
    logger.error "Database validation error: #{e.message}"
    error_response(e.message, 'validation_error')
  rescue ActiveRecord::RecordNotFound => e
    logger.error "Record not found: #{e.message}"
    error_response(e.message, 'not_found_error')
  rescue StandardError => e
    logger.error "Database operation failed: #{e.message}"
    error_response(e.message, 'database_error')
  end
  
  # Get current user from context
  def current_user
    user_id = @context[:user_id]
    return nil unless user_id
    
    @current_user ||= User.find_by(id: user_id)
  end
  
  # Check if user has permission for action
  def authorized?(action, resource = nil)
    user = current_user
    return false unless user
    
    # Basic authorization - can be extended with Pundit policies
    case action.to_s
    when 'read'
      true # All authenticated users can read
    when 'write', 'update', 'delete'
      user.role != 'user' || owns_resource?(resource)
    else
      false
    end
  end
  
  # Check if current user owns the resource
  def owns_resource?(resource)
    return false unless current_user && resource
    
    if resource.respond_to?(:user_id)
      resource.user_id == current_user.id
    elsif resource.respond_to?(:user)
      resource.user == current_user
    else
      false
    end
  end
  
  # Helper methods that would normally come from SuperAgent::AgentHelpers
  
  # Track AI usage and costs
  def track_ai_usage(context, cost, operation)
    logger.info "AI Usage: operation=#{operation}, cost=#{cost}, context=#{context[:agent_id]}"
    
    # Update user's AI credit usage if user is available
    if current_user&.respond_to?(:consume_ai_credit)
      current_user.consume_ai_credit(cost)
    end
  end
  
  # Check if AI budget is available for operation
  def ai_budget_available?(context, estimated_cost)
    # If no user context, assume budget is available (for system operations)
    return true unless current_user
    
    # Check if user can use AI features and has sufficient credits
    current_user.can_use_ai_features? && 
      (current_user.ai_credits_remaining || Float::INFINITY) >= estimated_cost
  end
end