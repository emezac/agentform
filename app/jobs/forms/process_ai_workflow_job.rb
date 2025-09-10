# frozen_string_literal: true

class Forms::ProcessAIWorkflowJob < ApplicationJob
  include CircuitBreaker::JobIntegration
  
  queue_as :ai_processing
  
  # Circuit breaker configuration
  circuit_breaker_options(
    failure_threshold: 5,    # Open after 5 failures
    recovery_timeout: 60,    # Try to close after 60 seconds
    expected_errors: [OpenAI::Error, Timeout::Error, Net::TimeoutError]
  )
  
  retry_on OpenAI::Error, wait: :exponentially_longer, attempts: 5
  retry_on Net::TimeoutError, wait: 10.seconds, attempts: 3
  retry_on StandardError, wait: 5.seconds, attempts: 3
  
  def perform(form_response_id, question_id, answer_data)
    # Pre-execution validations
    form_response = FormResponse.find(form_response_id)
    return unless should_process_ai?(form_response)
    
    # Apply intelligent rate limiting
    if rate_limited?(form_response.form)
      reschedule_job(5.minutes.from_now, form_response_id, question_id, answer_data)
      return
    end
    
    # Check user credits
    unless has_sufficient_credits?(form_response.form.user)
      Rails.logger.warn "Insufficient AI credits for user #{form_response.form.user_id}"
      return
    end
    
    # Execute with monitoring
    start_time = Time.current
    
    begin
      with_circuit_breaker do
        workflow = Forms::UniversalAIWorkflow.new
        result = workflow.run(
          form_response_id: form_response_id,
          question_id: question_id,
          answer_data: answer_data
        )
        
        # Log success
        log_execution_success(form_response_id, Time.current - start_time, result)
        
        # Update success metrics
        update_success_metrics(form_response.form)
        
        # Consume credits
        consume_ai_credits(form_response.form.user, calculate_execution_cost(result))
        
        result
      end
      
    rescue CircuitBreaker::OpenError => e
      Rails.logger.error "AI Circuit breaker open for form #{form_response.form_id}: #{e.message}"
      handle_circuit_breaker_open(form_response)
      
    rescue OpenAI::Error => e
      if e.message.include?("rate limit")
        Rails.logger.warn "OpenAI rate limit hit: #{e.message}"
        reschedule_job(30.seconds.from_now, form_response_id, question_id, answer_data)
      else
        Rails.logger.error "OpenAI API error: #{e.message}"
        raise e
      end
      
    rescue StandardError => e
      Rails.logger.error "AI Workflow failed for form #{form_response.form_id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      handle_workflow_error(form_response, e)
      update_failure_metrics(form_response.form)
      
      # Re-raise for retry
      raise e
    end
  end
  
  private
  
  def should_process_ai?(form_response)
    form = form_response.form
    
    # Check if AI is enabled
    return false unless form.ai_enhanced?
    
    # Check if this response has already been processed
    key = "ai_processed:#{form_response.id}"
    return false if Rails.cache.read(key)
    
    # Check if form is still active
    return false if form.status == 'archived'
    
    true
  end
  
  def rate_limited?(form)
    rate_limit_key = "ai_rate_limit:#{form.id}"
    current_count = Rails.cache.read(rate_limit_key) || 0
    
    # Get configurable limits from form AI config
    ai_config = form.ai_configuration
    max_requests = ai_config.dig('ai_engine', 'rate_limiting', 'max_requests_per_minute') || 10
    
    if current_count >= max_requests
      true
    else
      Rails.cache.write(rate_limit_key, current_count + 1, expires_in: 1.minute)
      false
    end
  end
  
  def has_sufficient_credits?(user)
    credits = user.ai_credits_remaining || 0
    credits >= 1 # Minimum 1 credit required
  end
  
  def consume_ai_credits(user, cost)
    current_credits = user.ai_credits_remaining || 0
    user.update!(ai_credits_remaining: [current_credits - cost, 0].max)
  end
  
  def calculate_execution_cost(result)
    # Placeholder - implement actual cost calculation based on tokens, model, etc.
    # For now, use fixed cost per execution
    1
  end
  
  def reschedule_job(delay, *args)
    self.class.set(wait: delay).perform_later(*args)
    Rails.logger.info "AI job rescheduled due to rate limiting: #{delay} delay"
  end
  
  def handle_circuit_breaker_open(form_response)
    # Notify administrators
    AdminNotificationMailer.ai_circuit_breaker_open(form_response.form).deliver_later
    
    # Mark system as degraded
    Rails.cache.write("ai_system_degraded:#{form_response.form_id}", true, expires_in: 10.minutes)
    
    # Log to monitoring system
    Rails.logger.error "AI Circuit breaker opened for form #{form_response.form_id}"
  end
  
  def handle_workflow_error(form_response, error)
    # Log detailed error
    error_details = {
      form_id: form_response.form_id,
      response_id: form_response.id,
      error_class: error.class.name,
      error_message: error.message,
      backtrace: error.backtrace.first(10),
      timestamp: Time.current.iso8601
    }
    
    Rails.logger.error("AI Workflow Error: #{error_details.to_json}")
    
    # Send error notification
    AdminNotificationMailer.ai_workflow_error(form_response.form, error).deliver_later
    
    # Mark response as having AI processing issues
    form_response.update!(ai_processing_error: error.message)
  end
  
  def log_execution_success(response_id, duration, result)
    Rails.logger.info({
      event: 'ai_workflow_success',
      response_id: response_id,
      duration_seconds: duration,
      questions_generated: result&.dig(:questions_generated) || 0,
      actions_executed: result&.dig(:additional_actions_executed) || 0,
      timestamp: Time.current.iso8601
    }.to_json)
  end
  
  def update_success_metrics(form)
    key = "ai_success_count:#{form.id}:#{Date.current}"
    Rails.cache.increment(key, 1)
    
    # Update form analytics
    Forms::AnalysisWorkflow.perform_async(form.id)
  end
  
  def update_failure_metrics(form)
    key = "ai_failure_count:#{form.id}:#{Date.current}"
    Rails.cache.increment(key, 1)
  end
end
