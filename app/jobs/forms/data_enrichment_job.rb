# frozen_string_literal: true

module Forms
  # Background job for enriching form response data with external company information
  # This job is triggered when a user provides their email address in a form
  # with AI enrichment enabled
  class DataEnrichmentJob < ApplicationJob
    queue_as :default
    
    # Maximum number of retry attempts
    retry_on StandardError, wait: :exponentially_longer, attempts: 3
    
    # Perform data enrichment for a form response
    # @param form_response_id [Integer] ID of the form response to enrich
    # @param email [String] Email address provided by the user
    def perform(form_response_id, email = nil)
      form_response = FormResponse.find(form_response_id)
      
      # Skip if form doesn't have AI enhancement enabled
      unless form_response.form.ai_enhanced?
        Rails.logger.info "Skipping enrichment - AI not enabled for form #{form_response.form.id}"
        return
      end
      
      # Skip if already enriched
      if form_response.enrichment_data.present?
        Rails.logger.info "Skipping enrichment - Already enriched for response #{form_response_id}"
        return
      end
      
      # Get email from response if not provided
      email ||= form_response.get_answer('email')
      
      unless email.present?
        Rails.logger.warn "No email found for enrichment in response #{form_response_id}"
        return
      end
      
      Rails.logger.info "Starting data enrichment for response #{form_response_id} with email #{email}"
      
      # Execute the enrichment workflow
      workflow_result = Forms::EnrichmentWorkflow.execute(
        form_response_id: form_response_id
      )

      Rails.logger.info "Starting data enrichment for response #{form_response_id} with email #{email}"
    
      # CORRECCIÓN: Usar WorkflowEngine
      context = SuperAgent::Workflow::Context.new(form_response_id: form_response_id)
      engine = SuperAgent::WorkflowEngine.new
      workflow_result = engine.execute(Forms::EnrichmentWorkflow, context)
      
      if workflow_result.completed?
        Rails.logger.info "Successfully enriched response #{form_response_id}"
      else
        Rails.logger.error "Failed to enrich response #{form_response_id}: #{workflow_result.error_message}"
        raise workflow_result.error if workflow_result.error.present?
      end
      
      if workflow_result.success?
        Rails.logger.info "Successfully enriched response #{form_response_id}"
      else
        Rails.logger.error "Failed to enrich response #{form_response_id}: #{workflow_result.error}"
        raise workflow_result.error if workflow_result.error.present?
      end
      
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "Form response #{form_response_id} not found for enrichment"
      raise e
    rescue StandardError => e
      Rails.logger.error "Data enrichment failed for response #{form_response_id}: #{e.message}"
      raise e
    end
    
    # Priority for this job type
    def self.priority
      5 # Medium priority
    end
    
    # Maximum runtime for this job
    def max_run_time
      5.minutes
    end
  end
end