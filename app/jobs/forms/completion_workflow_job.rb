# frozen_string_literal: true

module Forms
  # Background job responsible for processing form completion workflows
  # This job handles analytics updates, integration triggers, and completion-related tasks
  class CompletionWorkflowJob < ApplicationJob
    queue_as :default
    
    # Retry on specific errors that might be temporary
    retry_on StandardError, wait: :polynomially_longer, attempts: 2
    retry_on ActiveRecord::RecordNotFound, wait: 5.seconds, attempts: 3
    
    # Discard if records are not found or configuration is invalid
    discard_on ArgumentError
    
    def perform(form_response_id)
      log_progress("Starting completion workflow for form_response #{form_response_id}")
      
      # Find the form response and related records
      form_response = find_record(FormResponse, form_response_id)
      form = form_response.form
      
      # Validate that the form response is actually completed
      validate_completion_prerequisites!(form_response)
      
      # Process completion workflow steps
      results = process_completion_workflow(form_response, form)
      
      # Log completion
      log_progress("Completion workflow finished", {
        form_response_id: form_response.id,
        form_id: form.id,
        analytics_updated: results[:analytics_updated],
        integrations_triggered: results[:integrations_triggered],
        ai_analysis_queued: results[:ai_analysis_queued]
      })
      
      results
    rescue StandardError => e
      handle_completion_error(form_response_id, e)
    end
    
    private
    
    # Validate that completion processing is appropriate
    def validate_completion_prerequisites!(form_response)
      unless form_response.completed?
        raise ArgumentError, "Form response #{form_response.id} is not in completed state"
      end
      
      unless form_response.completed_at
        raise ArgumentError, "Form response #{form_response.id} missing completion timestamp"
      end
      
      log_progress("Completion prerequisites validated", {
        form_response_id: form_response.id,
        status: form_response.status,
        completed_at: form_response.completed_at
      })
    end
    
    # Process the main completion workflow
    def process_completion_workflow(form_response, form)
      results = {
        analytics_updated: false,
        integrations_triggered: false,
        ai_analysis_queued: false,
        errors: []
      }
      
      # Step 1: Update form analytics
      begin
        update_form_analytics(form, form_response)
        results[:analytics_updated] = true
        log_progress("Form analytics updated successfully")
      rescue StandardError => e
        results[:errors] << { step: 'analytics', error: e.message }
        Rails.logger.error "Failed to update form analytics: #{e.message}"
      end
      
      # Step 2: Update question-level analytics
      begin
        update_question_analytics(form_response)
        log_progress("Question analytics updated successfully")
      rescue StandardError => e
        results[:errors] << { step: 'question_analytics', error: e.message }
        Rails.logger.error "Failed to update question analytics: #{e.message}"
      end
      
      # Step 3: Trigger integrations if enabled
      if form.integrations_enabled?
        begin
          trigger_completion_integrations(form_response)
          results[:integrations_triggered] = true
          log_progress("Completion integrations triggered successfully")
        rescue StandardError => e
          results[:errors] << { step: 'integrations', error: e.message }
          Rails.logger.error "Failed to trigger integrations: #{e.message}"
        end
      end
      
      # Step 4: Queue AI analysis if enabled and sufficient responses
      if should_queue_ai_analysis?(form, form_response)
        begin
          queue_ai_analysis(form, form_response)
          results[:ai_analysis_queued] = true
          log_progress("AI analysis queued successfully")
        rescue StandardError => e
          results[:errors] << { step: 'ai_analysis', error: e.message }
          Rails.logger.error "Failed to queue AI analysis: #{e.message}"
        end
      end
      
      # Step 5: Update form completion metrics
      begin
        update_form_completion_metrics(form, form_response)
        log_progress("Form completion metrics updated successfully")
      rescue StandardError => e
        results[:errors] << { step: 'completion_metrics', error: e.message }
        Rails.logger.error "Failed to update completion metrics: #{e.message}"
      end
      
      # Step 6: Send completion notifications if configured
      if should_send_completion_notifications?(form)
        begin
          send_completion_notifications(form, form_response)
          log_progress("Completion notifications sent successfully")
        rescue StandardError => e
          results[:errors] << { step: 'notifications', error: e.message }
          Rails.logger.error "Failed to send completion notifications: #{e.message}"
        end
      end
      
      results
    end
    
    # Update form-level analytics with the new completion
    def update_form_analytics(form, form_response)
      safe_db_operation do
        # Update basic completion counts
        form.increment!(:completion_count)
        form.update!(updated_at: form_response.completed_at)
        
        # Update or create daily analytics record
        today = Date.current
        analytics = FormAnalytic.find_or_initialize_by(
          form: form,
          date: today,
          period_type: 'daily'
        )
        
        analytics.completed_responses_count = (analytics.completed_responses_count || 0) + 1
        
        # Calculate and update average completion time
        completion_time = calculate_completion_time(form_response)
        if completion_time
          current_avg = analytics.avg_completion_time || 0
          current_count = analytics.completed_responses_count
          
          # Calculate new average using incremental formula
          analytics.avg_completion_time = if current_count == 1
                                           completion_time
                                         else
                                           ((current_avg * (current_count - 1)) + completion_time) / current_count
                                         end
        end
        
        # Update quality and sentiment scores if available
        if form_response.ai_analysis.present?
          update_ai_metrics(analytics, form_response)
        end
        
        analytics.save!
        
        log_progress("Analytics updated", {
          form_id: form.id,
          date: today,
          completed_responses_count: analytics.completed_responses_count,
          avg_completion_time: analytics.avg_completion_time
        })
      end
    end
    
    # Update question-level analytics
    def update_question_analytics(form_response)
      form_response.question_responses.includes(:form_question).each do |question_response|
        question = question_response.form_question
        
        # Update question completion stats
        safe_db_operation do
          # This could be expanded to track question-specific metrics
          # For now, we'll update basic completion tracking
          question.touch(:updated_at)
        end
      end
    end
    
    # Trigger completion-specific integrations
    def trigger_completion_integrations(form_response)
      # Queue integration job with completion event
      Forms::IntegrationTriggerJob.perform_later(
        form_response.id,
        'form_completed',
        { source: 'completion_workflow' }
      )
      
      log_progress("Integration trigger job queued", {
        form_response_id: form_response.id,
        trigger_event: 'form_completed'
      })
    end
    
    # Determine if AI analysis should be queued
    def should_queue_ai_analysis?(form, form_response)
      return false unless form.ai_enhanced?
      return false unless form.user.can_use_ai_features?
      
      # Only queue analysis if form has sufficient responses for meaningful insights
      form.responses_count >= 5
    end
    
    # Queue AI analysis for the form
    def queue_ai_analysis(form, form_response)
      # Queue form-level analysis if we have enough responses
      if form.responses_count % 10 == 0 # Analyze every 10 completions
        Forms::AnalysisWorkflow.perform_later(form.id)
        log_progress("Form analysis workflow queued", { form_id: form.id })
      end
      
      # Queue individual response analysis if AI features are enabled
      if form_response.should_analyze_with_ai?
        Forms::ResponseAnalysisJob.perform_later(form_response.id)
        log_progress("Response analysis job queued", { form_response_id: form_response.id })
      end
    end
    
    # Update form completion metrics
    def update_form_completion_metrics(form, form_response)
      safe_db_operation do
        # Calculate completion rate
        total_responses = form.responses_count
        total_completions = form.completion_count
        completion_rate = total_responses > 0 ? (total_completions.to_f / total_responses * 100).round(2) : 0
        
        # Update form settings with latest metrics
        form_settings = form.form_settings || {}
        form_settings[:completion_rate] = completion_rate
        form_settings[:last_completion_at] = form_response.completed_at.iso8601
        form_settings[:completion_metrics_updated_at] = Time.current.iso8601
        
        form.update!(form_settings: form_settings)
        
        log_progress("Completion metrics updated", {
          form_id: form.id,
          completion_rate: completion_rate,
          total_responses: total_responses,
          total_completions: total_completions
        })
      end
    end
    
    # Determine if completion notifications should be sent
    def should_send_completion_notifications?(form)
      notification_settings = form.form_settings&.dig('notifications', 'completion')
      return false unless notification_settings
      
      notification_settings['enabled'] == true
    end
    
    # Send completion notifications
    def send_completion_notifications(form, form_response)
      notification_settings = form.form_settings.dig('notifications', 'completion')
      
      # Send email notification if configured
      if notification_settings['email_enabled']
        send_completion_email_notification(form, form_response, notification_settings)
      end
      
      # Send Slack notification if configured
      if notification_settings['slack_enabled']
        send_completion_slack_notification(form, form_response, notification_settings)
      end
      
      # Send webhook notification if configured
      if notification_settings['webhook_enabled']
        send_completion_webhook_notification(form, form_response, notification_settings)
      end
    end
    
    # Send email notification for completion
    def send_completion_email_notification(form, form_response, settings)
      # This would integrate with ActionMailer
      # For now, we'll log the action
      log_progress("Email notification would be sent", {
        form_id: form.id,
        form_response_id: form_response.id,
        recipients: settings['email_recipients']
      })
    end
    
    # Send Slack notification for completion
    def send_completion_slack_notification(form, form_response, settings)
      # This would integrate with Slack API
      # For now, we'll log the action
      log_progress("Slack notification would be sent", {
        form_id: form.id,
        form_response_id: form_response.id,
        channel: settings['slack_channel']
      })
    end
    
    # Send webhook notification for completion
    def send_completion_webhook_notification(form, form_response, settings)
      # This would trigger a webhook
      # For now, we'll log the action
      log_progress("Webhook notification would be sent", {
        form_id: form.id,
        form_response_id: form_response.id,
        webhook_url: settings['webhook_url']
      })
    end
    
    # Calculate completion time for a form response
    def calculate_completion_time(form_response)
      return nil unless form_response.started_at && form_response.completed_at
      
      # Return time in minutes
      ((form_response.completed_at - form_response.started_at) / 1.minute).round(2)
    end
    
    # Update AI-related metrics in analytics
    def update_ai_metrics(analytics, form_response)
      ai_results = form_response.ai_analysis
      
      # Update sentiment score
      if ai_results&.dig('overall_sentiment')
        current_sentiment = analytics.avg_sentiment_score || 0
        current_count = analytics.completed_responses_count
        
        new_sentiment = ai_results['overall_sentiment'].to_f
        analytics.avg_sentiment_score = if current_count == 1
                                         new_sentiment
                                       else
                                         ((current_sentiment * (current_count - 1)) + new_sentiment) / current_count
                                       end
      end
      
      # Update quality score
      if ai_results&.dig('overall_quality')
        current_quality = analytics.avg_quality_score || 0
        current_count = analytics.completed_responses_count
        
        new_quality = ai_results['overall_quality'].to_f
        analytics.avg_quality_score = if current_count == 1
                                       new_quality
                                     else
                                       ((current_quality * (current_count - 1)) + new_quality) / current_count
                                     end
      end
      
      # Update AI insights
      if ai_results&.dig('key_insights')
        analytics.ai_insights ||= {}
        analytics.ai_insights[:latest_insights] = ai_results['key_insights']
        analytics.ai_insights[:last_updated] = Time.current.iso8601
      end
    end
    
    # Handle completion workflow errors
    def handle_completion_error(form_response_id, error)
      error_context = {
        form_response_id: form_response_id,
        job_id: job_id,
        error_message: error.message,
        error_type: error.class.name
      }
      
      Rails.logger.error "Completion workflow failed for form_response #{form_response_id}: #{error.message}"
      Rails.logger.error error.backtrace.join("\n") if Rails.env.development?
      
      # Try to update form response with error information if possible
      begin
        form_response = FormResponse.find_by(id: form_response_id)
        if form_response
          completion_metadata = form_response.completion_data || {}
          completion_metadata[:workflow_errors] ||= []
          completion_metadata[:workflow_errors] << {
            error: error.message,
            error_type: error.class.name,
            failed_at: Time.current.iso8601,
            job_id: job_id
          }
          
          # Keep only last 3 errors
          completion_metadata[:workflow_errors] = completion_metadata[:workflow_errors].last(3)
          
          form_response.update!(completion_data: completion_metadata)
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
  end
end