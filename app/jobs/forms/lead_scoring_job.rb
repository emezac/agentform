# frozen_string_literal: true

module Forms
  # Background job responsible for scoring leads and routing them to appropriate teams
  class LeadScoringJob < ApplicationJob
    queue_as :ai_processing
    
    # Retry on specific errors that might be temporary
    retry_on StandardError, wait: :polynomially_longer, attempts: 2
    retry_on ActiveRecord::RecordNotFound, wait: 5.seconds, attempts: 3
    
    # Discard if records are not found or configuration is invalid
    discard_on ArgumentError
    
    def perform(form_response_id, options = {})
      log_progress("Starting lead scoring for form_response #{form_response_id}")
      
      # Find the form response and related records
      form_response = find_record(FormResponse, form_response_id)
      form = form_response.form
      
      # Validate prerequisites for lead scoring
      validate_scoring_prerequisites!(form_response, form)
      
      # Execute lead scoring workflow
      scoring_result = execute_scoring_workflow(form_response, form, options)
      
      # Log completion
      log_progress("Lead scoring completed", {
        form_response_id: form_response.id,
        form_id: form.id,
        score: scoring_result[:score],
        tier: scoring_result[:tier],
        routing_actions: scoring_result[:routing_actions]&.length || 0
      })
      
      scoring_result
    rescue StandardError => e
      handle_scoring_error(form_response_id, e)
    end
    
    private
    
    # Validate that lead scoring is appropriate and allowed
    def validate_scoring_prerequisites!(form_response, form)
      unless form_response.completed?
        raise ArgumentError, "Form response #{form_response.id} must be completed for lead scoring"
      end
      
      unless form.ai_enhanced?
        raise ArgumentError, "Form #{form.id} does not have AI features enabled"
      end
      
      # Check user's AI capabilities
      user = form.user
      unless user.can_use_ai_features?
        raise ArgumentError, "User #{user.id} does not have AI features available"
      end
      
      # Check if we've already scored this response
      if LeadScoring.exists?(form_response_id: form_response.id)
        raise ArgumentError, "Lead already scored for response #{form_response.id}"
      end
      
      log_progress("Lead scoring prerequisites validated", {
        form_response_id: form_response.id,
        form_id: form.id,
        ai_enabled: form.ai_enhanced?,
        user_can_use_ai: user.can_use_ai_features?
      })
    end
    
    # Execute the lead scoring workflow
    def execute_scoring_workflow(form_response, form, options)
      log_progress("Executing lead scoring workflow")
      
      begin
        # Prepare workflow inputs
        workflow_inputs = {
          form_response_id: form_response.id
        }
        
        # Execute the workflow
        workflow = Forms::LeadScoringWorkflow.new
        result = workflow.execute(workflow_inputs)
        
        # Check if workflow execution was successful
        if result.success?
          final_output = result.final_output
          
          if final_output.is_a?(Hash) && final_output[:lead_scoring_id]
            log_progress("Workflow executed successfully", {
              lead_scoring_id: final_output[:lead_scoring_id],
              score: final_output[:score],
              tier: final_output[:tier],
              ai_cost: final_output[:ai_cost]
            })
            
            # Trigger routing integrations based on scoring
            trigger_routing_integrations(form_response, final_output)
            
            {
              success: true,
              lead_scoring_id: final_output[:lead_scoring_id],
              score: final_output[:score],
              tier: final_output[:tier],
              routing_actions: final_output[:routing_actions],
              workflow_result: result
            }
          else
            log_progress("Workflow completed but generated skipped result", {
              final_output: final_output,
              reason: final_output[:reason] || 'Unknown'
            })
            
            {
              success: false,
              skipped: true,
              reason: final_output[:reason] || 'Lead scoring was skipped',
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
        Rails.logger.error "Lead scoring workflow failed: #{e.message}"
        
        {
          success: false,
          error: e.message,
          error_type: e.class.name
        }
      end
    end
    
    # Trigger routing integrations based on lead score
    def trigger_routing_integrations(form_response, scoring_result)
      log_progress("Triggering routing integrations based on lead score")
      
      tier = scoring_result[:tier]
      score = scoring_result[:score]
      
      # Determine integration triggers based on tier
      case tier
      when 'hot'
        # Immediate follow-up for hot leads
        trigger_immediate_followup(form_response, score, tier)
      when 'warm'
        # Scheduled follow-up for warm leads
        trigger_warm_followup(form_response, score, tier)
      when 'cold'
        # Nurture campaign for cold leads
        trigger_nurture_campaign(form_response, score, tier)
      end
    end
    
    # Trigger immediate follow-up for hot leads
    def trigger_immediate_followup(form_response, score, tier)
      log_progress("Triggering immediate follow-up for hot lead", {
        form_response_id: form_response.id,
        score: score
      })
      
      # Queue integration job with high priority
      Forms::IntegrationTriggerJob.perform_later(
        form_response.id,
        'hot_lead_qualified',
        {
          score: score,
          tier: tier,
          priority: 'critical',
          sla_hours: 1,
          channels: ['email', 'phone', 'slack'],
          assign_to: 'sales_team'
        }
      )
    end
    
    # Trigger scheduled follow-up for warm leads
    def trigger_warm_followup(form_response, score, tier)
      log_progress("Triggering scheduled follow-up for warm lead", {
        form_response_id: form_response.id,
        score: score
      })
      
      # Queue integration job with medium priority
      Forms::IntegrationTriggerJob.perform_later(
        form_response.id,
        'warm_lead_qualified',
        {
          score: score,
          tier: tier,
          priority: 'high',
          sla_hours: 24,
          channels: ['email', 'slack'],
          assign_to: 'marketing_team'
        }
      )
    end
    
    # Trigger nurture campaign for cold leads
    def trigger_nurture_campaign(form_response, score, tier)
      log_progress("Triggering nurture campaign for cold lead", {
        form_response_id: form_response.id,
        score: score
      })
      
      # Queue integration job with low priority
      Forms::IntegrationTriggerJob.perform_later(
        form_response.id,
        'cold_lead_nurture',
        {
          score: score,
          tier: tier,
          priority: 'medium',
          sla_hours: 72,
          channels: ['email'],
          campaign_type: 'nurture'
        }
      )
    end
    
    # Handle lead scoring errors
    def handle_scoring_error(form_response_id, error)
      error_context = {
        form_response_id: form_response_id,
        job_id: job_id,
        error_message: error.message,
        error_type: error.class.name
      }
      
      Rails.logger.error "Lead scoring failed for form_response #{form_response_id}: #{error.message}"
      Rails.logger.error error.backtrace.join("\n") if Rails.env.development?
      
      # Try to update form response with error information if possible
      begin
        form_response = FormResponse.find_by(id: form_response_id)
        if form_response
          # Add error information to the form response's AI analysis results
          current_analysis = form_response.ai_analysis_results || {}
          current_analysis[:lead_scoring_errors] ||= []
          current_analysis[:lead_scoring_errors] << {
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
  end
end