# frozen_string_literal: true

# Base workflow class for all SuperAgent workflows in this application
class ApplicationWorkflow < SuperAgent::WorkflowDefinition
  include SuperAgent::WorkflowHelpers
  
  # Class method to execute the workflow
  def self.execute(**params)
    # Create a context from the parameters
    context = SuperAgent::Workflow::Context.new(params)
    
    # Use the WorkflowEngine to execute
    engine = SuperAgent::WorkflowEngine.new
    result = engine.execute(self, context)
    
    # Return the result in a format compatible with the controller
    if result.success?
      # Get the final output from the last task
      final_output = result.respond_to?(:final_output) ? result.final_output : {}
      final_output.merge(success: true)
    else
      error_message = result.respond_to?(:error_message) ? result.error_message : result.error.to_s
      error_type = result.respond_to?(:error_type) ? result.error_type : 'workflow_error'
      
      {
        success: false,
        message: error_message,
        error_type: error_type
      }
    end
  rescue StandardError => e
    Rails.logger.error "Workflow execution failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    {
      success: false,
      message: e.message,
      error_type: 'execution_error'
    }
  end
  
  # Global workflow configuration
  # timeout 300 # 5 minutes default - TODO: Configure when SuperAgent supports it
  # retry_policy max_retries: 2, delay: 1 # TODO: Configure when SuperAgent supports it
  
  # TODO: Global error handling - Enable when SuperAgent supports it
  # on_error do |error, context|
  #   Rails.logger.error "Workflow error in #{self.class.name}: #{error.message}"
  #   Rails.logger.error error.backtrace.join("\n") if Rails.env.development?
  #   
  #   # Track error in Sentry if available
  #   if defined?(Sentry)
  #     Sentry.capture_exception(error, extra: { 
  #       workflow: self.class.name,
  #       context: context.to_h 
  #     })
  #   end
  #   
  #   {
  #     error: true,
  #     error_message: error.message,
  #     error_type: error.class.name,
  #     timestamp: Time.current.iso8601,
  #     workflow: self.class.name
  #   }
  # end
  
  # TODO: Common workflow hooks - Enable when SuperAgent supports it
  # before_all do |context|
  #   Rails.logger.info "Starting workflow #{self.class.name}"
  #   context.set(:workflow_started_at, Time.current)
  #   context.set(:workflow_id, SecureRandom.uuid)
  #   
  #   # Initialize AI usage tracking
  #   context.set(:ai_usage, {
  #     total_cost: 0.0,
  #     operations: [],
  #     budget_limit: Rails.application.config.ai_budget_per_workflow || 1.0
  #   })
  # end
  # 
  # after_all do |context|
  #   started_at = context.get(:workflow_started_at)
  #   duration = started_at ? Time.current - started_at : 0
  #   ai_usage = context.get(:ai_usage)
  #   
  #   Rails.logger.info "Completed workflow #{self.class.name} in #{duration.round(2)}s"
  #   Rails.logger.info "AI usage: $#{ai_usage[:total_cost].round(4)} across #{ai_usage[:operations].length} operations"
  #   
  #   # Store workflow metrics if needed
  #   store_workflow_metrics(context, duration, ai_usage) if respond_to?(:store_workflow_metrics, true)
  # end
  
  protected
  
  # Helper method to track AI usage and costs
  def track_ai_usage(context, cost, operation)
    ai_usage = context.get(:ai_usage)
    
    ai_usage[:total_cost] += cost.to_f
    ai_usage[:operations] << {
      operation: operation,
      cost: cost.to_f,
      timestamp: Time.current.iso8601
    }
    
    context.set(:ai_usage, ai_usage)
    
    Rails.logger.debug "AI operation '#{operation}' cost: $#{cost.round(4)}, total: $#{ai_usage[:total_cost].round(4)}"
    
    ai_usage
  end
  
  # Helper method to check if AI budget is available
  def ai_budget_available?(context, estimated_cost)
    ai_usage = context.get(:ai_usage)
    budget_limit = ai_usage[:budget_limit]
    
    return true if budget_limit.nil? || budget_limit <= 0 # No limit set
    
    projected_total = ai_usage[:total_cost] + estimated_cost.to_f
    available = projected_total <= budget_limit
    
    unless available
      Rails.logger.warn "AI budget exceeded: projected $#{projected_total.round(4)} > limit $#{budget_limit}"
    end
    
    available
  end
  
  # Helper method to get form context
  def get_form_context(form_id)
    form = Form.find(form_id)
    {
      form_id: form.id,
      form_name: form.name,
      form_category: form.category,
      ai_enhanced: form.ai_enhanced?,
      ai_model: form.ai_model || 'gpt-3.5-turbo',
      questions_count: form.form_questions.count,
      settings: form.settings
    }
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error "Form not found: #{form_id}"
    nil
  end
  
  # Helper method to get response context
  def get_response_context(response_id)
    response = FormResponse.find(response_id)
    {
      response_id: response.id,
      form_id: response.form_id,
      status: response.status,
      progress: response.progress_percentage,
      session_id: response.session_id,
      answers_count: response.question_responses.count,
      created_at: response.created_at
    }
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error "FormResponse not found: #{response_id}"
    nil
  end
  
  # Helper method to get question context
  def get_question_context(question_id)
    question = FormQuestion.find(question_id)
    {
      question_id: question.id,
      form_id: question.form_id,
      title: question.title,
      question_type: question.question_type,
      required: question.required?,
      ai_enhanced: question.ai_enhanced?,
      position: question.position,
      configuration: question.question_config
    }
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error "FormQuestion not found: #{question_id}"
    nil
  end
  
  # Helper method to validate workflow inputs
  def validate_required_inputs(context, *required_keys)
    missing_keys = required_keys.select { |key| context.get(key).nil? }
    
    if missing_keys.any?
      error_message = "Missing required inputs: #{missing_keys.join(', ')}"
      Rails.logger.error error_message
      raise ArgumentError, error_message
    end
    
    true
  end
  
  # Helper method to safely execute database operations
  def safe_db_operation
    ActiveRecord::Base.transaction do
      yield
    end
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Database validation error: #{e.message}"
    { error: true, message: e.message, type: 'validation_error' }
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "Record not found: #{e.message}"
    { error: true, message: e.message, type: 'not_found_error' }
  rescue StandardError => e
    Rails.logger.error "Database operation failed: #{e.message}"
    { error: true, message: e.message, type: 'database_error' }
  end
  
  # Helper method to format workflow results
  def format_success_result(data = {})
    {
      success: true,
      timestamp: Time.current.iso8601,
      workflow: self.class.name
    }.merge(data)
  end
  
  # Helper method to format error results
  def format_error_result(message, type = 'workflow_error', data = {})
    {
      error: true,
      error_message: message,
      error_type: type,
      timestamp: Time.current.iso8601,
      workflow: self.class.name
    }.merge(data)
  end
  
  private
  
  # Store workflow execution metrics
  def store_workflow_metrics(context, duration, ai_usage)
    # This could be extended to store metrics in a dedicated table
    # or send to an analytics service
    Rails.logger.info "Workflow metrics stored for #{self.class.name}"
  end
end