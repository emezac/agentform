# frozen_string_literal: true

module Forms
  # Background job responsible for generating SuperAgent workflow classes for forms
  # This job is triggered when a form is published or when workflow regeneration is requested
  class WorkflowGenerationJob < ApplicationJob
    queue_as :ai_processing
    
    # Retry on specific errors that might be temporary
    retry_on StandardError, wait: :exponentially_longer, attempts: 3
    
    # Discard if form is not found or invalid
    discard_on ActiveRecord::RecordNotFound, ArgumentError
    
    def perform(form_id, options = {})
      log_progress("Starting workflow generation for form #{form_id}")
      
      # Find the form
      form = find_record(Form, form_id)
      
      # Validate form is ready for workflow generation
      validate_form_for_workflow_generation!(form)
      
      # Generate the workflow class
      result = generate_workflow_class(form, options)
      
      # Update form with generated workflow class name
      update_form_with_workflow(form, result) if result[:success]
      
      # Log completion
      log_progress("Workflow generation completed", {
        form_id: form.id,
        workflow_class: result[:workflow_class_name],
        success: result[:success]
      })
      
      result
    rescue StandardError => e
      handle_workflow_generation_error(form_id, e)
    end
    
    private
    
    # Validate that the form is ready for workflow generation
    def validate_form_for_workflow_generation!(form)
      unless form.ai_enabled?
        raise ArgumentError, "Form #{form.id} does not have AI features enabled"
      end
      
      unless form.form_questions.any?
        raise ArgumentError, "Form #{form.id} must have at least one question to generate workflow"
      end
      
      if form.draft?
        Rails.logger.warn "Generating workflow for draft form #{form.id} - this is unusual"
      end
      
      log_progress("Form validation passed", {
        form_id: form.id,
        questions_count: form.form_questions.count,
        ai_enhanced_questions: form.form_questions.count { |q| q.ai_enhanced? }
      })
    end
    
    # Generate the workflow class using the service
    def generate_workflow_class(form, options = {})
      log_progress("Generating workflow class for form #{form.id}")
      
      safe_db_operation do
        # Use the workflow generator service
        service = execute_service(Forms::WorkflowGeneratorService, form)
        
        if service
          workflow_class = service
          workflow_class_name = form.workflow_class || generate_workflow_class_name(form)
          
          log_progress("Workflow class generated successfully", {
            form_id: form.id,
            workflow_class_name: workflow_class_name,
            class_methods: workflow_class.instance_methods(false).count
          })
          
          {
            success: true,
            workflow_class: workflow_class,
            workflow_class_name: workflow_class_name,
            generated_at: Time.current
          }
        else
          {
            success: false,
            error: "Workflow generation service returned nil",
            form_id: form.id
          }
        end
      end
    rescue StandardError => e
      log_progress("Workflow generation failed", {
        form_id: form.id,
        error: e.message
      })
      
      {
        success: false,
        error: e.message,
        error_type: e.class.name,
        form_id: form.id
      }
    end
    
    # Update the form with the generated workflow class information
    def update_form_with_workflow(form, generation_result)
      log_progress("Updating form with workflow information")
      
      safe_db_operation do
        # Update the workflow_class field and store metadata in workflow_config
        form.update!(
          workflow_class: generation_result[:workflow_class_name],
          workflow_config: form.workflow_config.merge({
            job_id: job_id,
            generated_at: generation_result[:generated_at],
            class_name: generation_result[:workflow_class_name],
            generation_version: 1,
            last_generation_job_id: job_id
          })
        )
        
        log_progress("Form updated successfully", {
          form_id: form.id,
          workflow_class_name: generation_result[:workflow_class_name]
        })
      end
    rescue StandardError => e
      Rails.logger.error "Failed to update form #{form.id} with workflow information: #{e.message}"
      
      # Don't re-raise here as the workflow was generated successfully
      # Just log the error and continue
      if defined?(Sentry)
        Sentry.capture_exception(e, extra: {
          form_id: form.id,
          workflow_class_name: generation_result[:workflow_class_name],
          job_id: job_id
        })
      end
    end
    
    # Generate a unique workflow class name for the form
    def generate_workflow_class_name(form)
      # Create a unique class name based on form ID
      form_identifier = form.id.to_s.gsub('-', '').first(8).upcase
      "Forms::Form#{form_identifier}Workflow"
    end
    
    # Handle workflow generation errors
    def handle_workflow_generation_error(form_id, error)
      error_context = {
        form_id: form_id,
        job_id: job_id,
        error_message: error.message,
        error_type: error.class.name
      }
      
      Rails.logger.error "Workflow generation failed for form #{form_id}: #{error.message}"
      Rails.logger.error error.backtrace.join("\n") if Rails.env.development?
      
      # Try to update form with error information if possible
      begin
        form = Form.find_by(id: form_id)
        if form
          form.update!(
            workflow_config: form.workflow_config.merge({
              generation_error: {
                error: error.message,
                error_type: error.class.name,
                failed_at: Time.current,
                job_id: job_id
              }
            })
          )
        end
      rescue StandardError => update_error
        Rails.logger.error "Failed to update form with error information: #{update_error.message}"
      end
      
      # Track error in monitoring system
      if defined?(Sentry)
        Sentry.capture_exception(error, extra: error_context)
      end
      
      # Re-raise to trigger retry logic
      raise error
    end
    
    # Check if workflow class exists and is valid
    def validate_generated_workflow(workflow_class_name)
      return false unless workflow_class_name.present?
      
      begin
        workflow_class = workflow_class_name.constantize
        
        # Basic validation that it's a workflow class
        return false unless workflow_class.ancestors.include?(ApplicationWorkflow)
        
        # Check that it has the expected methods
        required_methods = [:workflow, :execute]
        required_methods.all? { |method| workflow_class.method_defined?(method) }
      rescue NameError
        false
      end
    end
    
    # Clean up any existing workflow class before regeneration
    def cleanup_existing_workflow(form)
      return unless form.workflow_class.present?
      
      begin
        existing_class = form.workflow_class.constantize
        
        # Remove the constant to allow redefinition
        namespace, class_name = form.workflow_class.split('::')
        if namespace && class_name
          namespace.constantize.send(:remove_const, class_name)
        else
          Object.send(:remove_const, form.workflow_class)
        end
        
        log_progress("Cleaned up existing workflow class", {
          form_id: form.id,
          old_class_name: form.workflow_class
        })
      rescue NameError
        # Class doesn't exist, nothing to clean up
        log_progress("No existing workflow class to clean up")
      rescue StandardError => e
        Rails.logger.warn "Failed to clean up existing workflow class: #{e.message}"
      end
    end
  end
end