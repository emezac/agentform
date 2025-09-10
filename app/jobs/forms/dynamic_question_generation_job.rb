# frozen_string_literal: true

module Forms
  # Background job responsible for generating dynamic follow-up questions using AI
  # This job is triggered when a response analysis suggests a follow-up question would be valuable
  class DynamicQuestionGenerationJob < ApplicationJob
    queue_as :ai_processing
    
    # Retry on specific errors that might be temporary
    retry_on StandardError, wait: :polynomially_longer, attempts: 2
    
    # Discard if records are not found or invalid
    discard_on ActiveRecord::RecordNotFound, ArgumentError
    
    def perform(form_response_id, source_question_id, options = {})
      log_progress("Starting dynamic question generation for form_response #{form_response_id}, source_question #{source_question_id}")
      
      # Find the required records
      form_response = find_record(FormResponse, form_response_id)
      source_question = find_record(FormQuestion, source_question_id)
      
      # Validate prerequisites for dynamic question generation
      validate_generation_prerequisites!(form_response, source_question)
      
      # Get the source answer data
      source_answer_data = get_source_answer_data(form_response, source_question)
      
      # Execute dynamic question generation workflow
      generation_result = execute_generation_workflow(form_response, source_question, source_answer_data, options)
      
      # Log completion
      log_progress("Dynamic question generation completed", {
        form_response_id: form_response.id,
        source_question_id: source_question.id,
        success: generation_result[:success],
        dynamic_question_id: generation_result[:dynamic_question_id]
      })
      
      generation_result
    rescue StandardError => e
      handle_generation_error(form_response_id, source_question_id, e)
    end
    
    private
    
    # Validate that dynamic question generation is appropriate and allowed
    def validate_generation_prerequisites!(form_response, source_question)
      form = source_question.form
      user = form.user
      
      # Verify form response belongs to the same form as the source question
      unless form_response.form_id == source_question.form_id
        raise ArgumentError, "Form response #{form_response.id} does not belong to form #{source_question.form_id}"
      end
      
      # Check if form has AI features enabled
      unless form.ai_enhanced?
        raise ArgumentError, "Form #{form.id} does not have AI features enabled"
      end
      
      # Check if source question supports dynamic follow-ups
      unless source_question.generates_followups?
        raise ArgumentError, "Source question #{source_question.id} is not configured for follow-up generation"
      end
      
      # Check user's AI capabilities
      unless user.can_use_ai_features?
        raise ArgumentError, "User #{user.id} does not have AI features available"
      end
      
      # Check if we've already generated too many dynamic questions for this response
      existing_count = form_response.dynamic_questions.count
      max_dynamic_questions = form.ai_configuration&.dig('max_dynamic_questions') || 3
      
      if existing_count >= max_dynamic_questions
        raise ArgumentError, "Maximum dynamic questions limit reached (#{existing_count}/#{max_dynamic_questions})"
      end
      
      # Check if we've already generated follow-ups for this specific question
      existing_from_source = form_response.dynamic_questions
                                         .where(generated_from_question: source_question)
                                         .count
      max_per_question = source_question.ai_configuration&.dig('max_followups') || 2
      
      if existing_from_source >= max_per_question
        raise ArgumentError, "Maximum follow-ups for this question reached (#{existing_from_source}/#{max_per_question})"
      end
      
      # Check if form response is still active (not completed too long ago)
      if form_response.completed? && form_response.completed_at < 1.hour.ago
        raise ArgumentError, "Form response was completed too long ago for dynamic questions"
      end
      
      log_progress("Dynamic question generation prerequisites validated", {
        form_response_id: form_response.id,
        source_question_id: source_question.id,
        existing_dynamic_count: existing_count,
        existing_from_source: existing_from_source,
        form_ai_enabled: form.ai_enhanced?,
        user_can_use_ai: user.can_use_ai_features?
      })
    end
    
    # Get the answer data for the source question from the form response
    def get_source_answer_data(form_response, source_question)
      # Find the question response for the source question
      question_response = form_response.question_responses
                                      .find_by(form_question: source_question)
      
      unless question_response
        raise ArgumentError, "No response found for source question #{source_question.id}"
      end
      
      unless question_response.answer_data.present?
        raise ArgumentError, "Source question response has no answer data"
      end
      
      log_progress("Retrieved source answer data", {
        question_response_id: question_response.id,
        answer_present: question_response.answer_data.present?,
        answer_type: question_response.answer_data.class.name
      })
      
      question_response.answer_data
    end
    
    # Execute the dynamic question generation workflow
    def execute_generation_workflow(form_response, source_question, source_answer_data, options)
      log_progress("Executing dynamic question generation workflow")
      
      begin
        # Prepare workflow inputs
        workflow_inputs = {
          form_response_id: form_response.id,
          source_question_id: source_question.id,
          source_answer_data: source_answer_data,
          generation_trigger: options[:trigger] || 'manual'
        }
        
        # Execute the workflow
        workflow = Forms::DynamicQuestionWorkflow.new
        result = workflow.execute(workflow_inputs)
        
        # Check if workflow execution was successful
        if result.success?
          final_output = result.final_output
          
          if final_output.is_a?(Hash) && final_output[:dynamic_question_id]
            log_progress("Workflow executed successfully", {
              dynamic_question_id: final_output[:dynamic_question_id],
              ai_cost: final_output[:ai_cost],
              strategy: final_output[:strategy]&.dig(:type)
            })
            
            {
              success: true,
              dynamic_question_id: final_output[:dynamic_question_id],
              dynamic_question: final_output[:dynamic_question],
              ai_cost: final_output[:ai_cost],
              strategy: final_output[:strategy],
              workflow_result: result
            }
          else
            log_progress("Workflow completed but no dynamic question was generated", {
              final_output: final_output,
              reason: final_output[:reason] || 'Unknown'
            })
            
            {
              success: false,
              skipped: true,
              reason: final_output[:reason] || 'Generation was skipped',
              workflow_result: result
            }
          end
        else
          error_message = result.error_message || 'Workflow execution failed'
          
          log_progress("Workflow execution failed", {
            error: error_message,
            error_type: result.error_type
          })
          
          {
            success: false,
            error: error_message,
            error_type: result.error_type || 'workflow_error',
            workflow_result: result
          }
        end
      rescue StandardError => e
        Rails.logger.error "Dynamic question generation workflow failed: #{e.message}"
        
        {
          success: false,
          error: e.message,
          error_type: e.class.name
        }
      end
    end
    
    # Handle generation errors
    def handle_generation_error(form_response_id, source_question_id, error)
      error_context = {
        form_response_id: form_response_id,
        source_question_id: source_question_id,
        job_id: job_id,
        error_message: error.message,
        error_type: error.class.name
      }
      
      Rails.logger.error "Dynamic question generation failed for form_response #{form_response_id}, source_question #{source_question_id}: #{error.message}"
      Rails.logger.error error.backtrace.join("\n") if Rails.env.development?
      
      # Try to log the error in the form response if possible
      begin
        form_response = FormResponse.find_by(id: form_response_id)
        if form_response
          # Add error information to the form response's AI analysis results
          current_analysis = form_response.ai_analysis_results || {}
          current_analysis[:dynamic_question_errors] ||= []
          current_analysis[:dynamic_question_errors] << {
            source_question_id: source_question_id,
            error: error.message,
            error_type: error.class.name,
            failed_at: Time.current.iso8601,
            job_id: job_id
          }
          
          form_response.update!(ai_analysis_results: current_analysis)
        end
      rescue StandardError => update_error
        Rails.logger.error "Failed to update form response with error information: #{update_error.message}"
      end
      
      # Track error in monitoring system
      if defined?(Sentry)
        Sentry.capture_exception(error, extra: error_context)
      end
      
      # Re-raise to trigger retry logic
      raise error
    end
    
    # Check if AI budget is available for this operation
    def check_ai_budget(user, estimated_cost)
      return true unless user.respond_to?(:ai_credits_remaining)
      
      remaining_credits = user.ai_credits_remaining
      
      if remaining_credits < estimated_cost
        log_progress("Insufficient AI credits", {
          user_id: user.id,
          remaining_credits: remaining_credits,
          estimated_cost: estimated_cost
        })
        return false
      end
      
      true
    end
    
    # Validate that the generated dynamic question is appropriate
    def validate_generated_question(dynamic_question, source_question, form_response)
      return false unless dynamic_question.persisted?
      
      # Check that it's not too similar to existing questions
      existing_questions = form_response.form.form_questions.pluck(:title)
      existing_dynamic_questions = form_response.dynamic_questions.where.not(id: dynamic_question.id).pluck(:title)
      all_existing = existing_questions + existing_dynamic_questions
      
      # Simple similarity check
      similar_question = all_existing.find do |existing_title|
        calculate_text_similarity(dynamic_question.title, existing_title) > 0.8
      end
      
      if similar_question
        log_progress("Generated question too similar to existing question", {
          generated_title: dynamic_question.title,
          similar_to: similar_question,
          dynamic_question_id: dynamic_question.id
        })
        return false
      end
      
      # Check that it's not asking for the same information as the source
      if calculate_text_similarity(dynamic_question.title, source_question.title) > 0.7
        log_progress("Generated question too similar to source question", {
          generated_title: dynamic_question.title,
          source_title: source_question.title,
          dynamic_question_id: dynamic_question.id
        })
        return false
      end
      
      true
    end
    
    # Calculate text similarity between two strings
    def calculate_text_similarity(text1, text2)
      return 0.0 if text1.blank? || text2.blank?
      
      words1 = text1.downcase.split(/\W+/).reject(&:blank?)
      words2 = text2.downcase.split(/\W+/).reject(&:blank?)
      
      return 0.0 if words1.empty? || words2.empty?
      
      common_words = words1 & words2
      total_unique_words = (words1 | words2).length
      
      common_words.length.to_f / total_unique_words
    end
    
    # Schedule follow-up analysis if the dynamic question gets answered
    def schedule_followup_analysis(dynamic_question)
      return unless dynamic_question.should_generate_followup?
      
      log_progress("Scheduling follow-up analysis for dynamic question", {
        dynamic_question_id: dynamic_question.id,
        form_response_id: dynamic_question.form_response_id
      })
      
      # This could trigger another round of dynamic question generation
      # or other analysis workflows based on the answer
      Forms::ResponseAnalysisJob.perform_later(dynamic_question.id)
    end
    
    # Update form analytics with dynamic question generation metrics
    def update_form_analytics(form, generation_result)
      return unless generation_result[:success]
      
      safe_db_operation do
        # Find or create analytics record for today
        analytics = FormAnalytic.find_or_create_by(
          form: form,
          date: Date.current
        ) do |record|
          record.initialize_metrics
        end
        
        # Update dynamic question metrics
        current_metrics = analytics.metrics || {}
        dynamic_metrics = current_metrics['dynamic_questions'] ||= {}
        
        dynamic_metrics['generated_count'] = (dynamic_metrics['generated_count'] || 0) + 1
        dynamic_metrics['total_ai_cost'] = (dynamic_metrics['total_ai_cost'] || 0.0) + (generation_result[:ai_cost] || 0.0)
        dynamic_metrics['last_generated_at'] = Time.current.iso8601
        
        # Track strategy types
        strategy_type = generation_result[:strategy]&.dig(:type)
        if strategy_type
          strategy_counts = dynamic_metrics['strategy_counts'] ||= {}
          strategy_counts[strategy_type] = (strategy_counts[strategy_type] || 0) + 1
        end
        
        analytics.update!(metrics: current_metrics)
        
        log_progress("Updated form analytics with dynamic question metrics", {
          form_id: form.id,
          generated_count: dynamic_metrics['generated_count'],
          strategy_type: strategy_type
        })
      end
    rescue StandardError => e
      Rails.logger.error "Failed to update form analytics: #{e.message}"
      # Don't re-raise as this is not critical
    end
  end
end