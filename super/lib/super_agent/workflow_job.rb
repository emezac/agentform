# frozen_string_literal: true

require 'securerandom'

module SuperAgent
  # ActiveJob for executing workflows asynchronously
  #
  # This job handles the execution of workflows in the background,
  # providing a Rails-native way to run complex AI workflows asynchronously.
  #
  # @example Usage in an agent
  #   class LeadAgent < SuperAgent::Base
  #     def analyze_lead_async(lead_data)
  #       run_workflow_later(LeadAnalysisWorkflow, initial_input: lead_data)
  #       render json: { message: "Analysis started" }
  #     end
  #   end
  #
  class WorkflowJob < ActiveJob::Base
    queue_as :default

    # Execute a workflow asynchronously
    #
    # @param workflow_class_name [String] The full class name of the workflow
    # @param context_data [Hash] The serialized context data
    # @return [void]
    def perform(workflow_class_name, context_data)
      execution = create_execution_record(workflow_class_name, context_data)
      execution.start!
      
      workflow_class = Object.const_get(workflow_class_name)
      context = rehydrate_context(context_data)
      
      engine = SuperAgent::WorkflowEngine.new
      result = engine.execute(workflow_class, context)
      
      execution.update_with_result(result)
      
      # Log the async completion
      SuperAgent.configuration.logger.info(
        "Async workflow completed",
        workflow: workflow_class_name,
        job_id: job_id,
        execution_id: execution.workflow_execution_id,
        status: result.status,
        duration_ms: result.duration_ms
      )
      
      result
    rescue StandardError => e
      # Update execution with error
      if defined?(execution) && execution
        execution.update_with_result(
          SuperAgent::WorkflowResult.new(
            status: 'failed',
            error: e.message,
            failed_task_name: nil,
            full_trace: [],
            final_output: {},
            duration_ms: 0
          )
        )
      end
      
      SuperAgent.configuration.logger.error(
        "Async workflow job failed",
        workflow: workflow_class_name,
        job_id: job_id,
        error: e.message,
        error_class: e.class.name
      )
      raise
    end

    private

    def create_execution_record(workflow_class_name, context_data)
      SuperAgent::Execution.create!(
        workflow_class_name: workflow_class_name,
        initial_context: context_data,
        job_id: job_id
      )
    end

    def rehydrate_context(context_data)
      # Rehydrate GlobalID objects
      rehydrated_hash = context_data.deep_dup
      
      rehydrated_hash.each do |key, value|
        if value.is_a?(String) && value.start_with?('gid://')
          rehydrated_hash[key] = GlobalID::Locator.locate(value)
        elsif value.is_a?(Array)
          rehydrated_hash[key] = value.map do |item|
            item.is_a?(String) && item.start_with?('gid://') ? 
              GlobalID::Locator.locate(item) : item
          end
        elsif value.is_a?(Hash)
          rehydrated_hash[key] = rehydrate_context(value)
        end
      end

      SuperAgent::Workflow::Context.new(**rehydrated_hash)
    end
  end
end