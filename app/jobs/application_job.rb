# frozen_string_literal: true

# Base job class for all background jobs in this application
class ApplicationJob < ActiveJob::Base
  include SuperAgent::JobHelpers if defined?(SuperAgent::JobHelpers)
  
  # Automatically retry jobs that encountered a deadlock
  retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3
  
  # Most jobs are safe to ignore if the underlying records are no longer available
  discard_on ActiveJob::DeserializationError
  
  # Retry on temporary failures
  retry_on StandardError, wait: :exponentially_longer, attempts: 5
  
  # Discard jobs that are clearly invalid
  discard_on ArgumentError, ActiveRecord::RecordNotFound
  
  # Queue configuration
  queue_as do
    case self.class.name
    when /Critical/
      :critical
    when /AI/, /Analysis/, /LLM/
      :ai_processing
    when /Integration/, /Webhook/, /API/
      :integrations
    when /Analytics/, /Report/
      :analytics
    else
      :default
    end
  end
  
  # Global job callbacks
  before_perform do |job|
    Rails.logger.info "Starting job #{job.class.name} with arguments: #{job.arguments.inspect}"
    job.instance_variable_set(:@job_started_at, Time.current)
  end
  
  after_perform do |job|
    started_at = job.instance_variable_get(:@job_started_at)
    duration = started_at ? Time.current - started_at : 0
    Rails.logger.info "Completed job #{job.class.name} in #{duration.round(2)}s"
  end
  
  around_perform do |job, block|
    # Add job context for error tracking
    if defined?(Sentry)
      Sentry.with_scope do |scope|
        if scope
          scope.set_tag(:job_class, job.class.name)
          scope.set_tag(:job_queue, job.queue_name)
          scope.set_context(:job_arguments, job.arguments)
        end
        block.call
      end
    else
      block.call
    end
  end
  
  protected
  
  # Execute a workflow from within a job
  def execute_workflow(workflow_class, inputs = {})
    Rails.logger.info "Job #{self.class.name} executing workflow #{workflow_class.name}"
    
    begin
      context = SuperAgent::Workflow::Context.new(inputs.merge(job_context))
      engine = SuperAgent::WorkflowEngine.new
      result = engine.execute(workflow_class, context)

      log_workflow_result(workflow_class, result)
      result
    rescue StandardError => e
      Rails.logger.error "Workflow execution failed in job #{self.class.name}: #{e.message}"
      handle_workflow_error(workflow_class, e)
    end
  end
  
  # Execute a service from within a job
  def execute_service(service_class, *args)
    Rails.logger.info "Job #{self.class.name} executing service #{service_class.name}"
    
    service = service_class.call(*args)
    
    if service.failure?
      Rails.logger.error "Service execution failed: #{service.errors.full_messages.join(', ')}"
      raise StandardError, "Service #{service_class.name} failed: #{service.errors.full_messages.join(', ')}"
    end
    
    service.result
  end
  
  # Get job context for workflows and services
  def job_context
    {
      job_id: job_id,
      job_class: self.class.name,
      queue_name: queue_name,
      enqueued_at: enqueued_at,
      executions: executions
    }
  end
  
  # Safe database operation with error handling
  def safe_db_operation
    ActiveRecord::Base.transaction do
      yield
    end
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Database validation error in job #{self.class.name}: #{e.message}"
    raise e
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "Record not found in job #{self.class.name}: #{e.message}"
    raise e
  rescue StandardError => e
    Rails.logger.error "Database operation failed in job #{self.class.name}: #{e.message}"
    raise e
  end
  
  # Find record with error handling
  def find_record(model_class, id)
    record = model_class.find_by(id: id)
    
    unless record
      error_message = "#{model_class.name} not found with id: #{id}"
      Rails.logger.error error_message
      raise ActiveRecord::RecordNotFound, error_message
    end
    
    record
  end
  
  # Check if job should continue based on record state
  def should_continue?(record, expected_state = nil)
    return false unless record
    
    if expected_state && record.respond_to?(:status)
      return record.status == expected_state.to_s
    end
    
    true
  end
  
  # Log job progress
  def log_progress(message, details = {})
    Rails.logger.info "Job #{self.class.name} progress: #{message}"
    Rails.logger.debug "Details: #{details.inspect}" if details.any?
  end
  
  # Handle job-specific errors
  def handle_job_error(error, context = {})
    Rails.logger.error "Job #{self.class.name} error: #{error.message}"
    Rails.logger.error error.backtrace.join("\n") if Rails.env.development?
    
    # Track error in Sentry if available
    if defined?(Sentry)
      Sentry.capture_exception(error, extra: {
        job_class: self.class.name,
        job_id: job_id,
        queue_name: queue_name,
        context: context
      })
    end
    
    # Re-raise to trigger retry logic
    raise error
  end
  
  private
  
  # Handle workflow execution errors
  def handle_workflow_error(workflow_class, error)
    Rails.logger.error "Workflow #{workflow_class.name} failed in job #{self.class.name}: #{error.message}"
    
    # Track error but don't re-raise to allow job to complete
    if defined?(Sentry)
      Sentry.capture_exception(error, extra: {
        job_class: self.class.name,
        workflow_class: workflow_class.name,
        job_context: job_context
      })
    end
    
    {
      error: true,
      error_message: error.message,
      error_type: error.class.name,
      workflow: workflow_class.name,
      job: self.class.name
    }
  end
  
  # Log workflow execution results
  def log_workflow_result(workflow_class, result)
    if result.is_a?(Hash) && result[:error]
      Rails.logger.error "Workflow #{workflow_class.name} completed with error: #{result[:error_message]}"
    else
      Rails.logger.info "Workflow #{workflow_class.name} completed successfully"
    end
  end
end
