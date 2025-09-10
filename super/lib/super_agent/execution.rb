# frozen_string_literal: true

module SuperAgent
  # Model for tracking workflow executions
  # This provides observability for async workflows
  class Execution
    attr_accessor :id, :workflow_class_name, :status, :initial_context, 
                  :final_output, :error, :failed_task_name, :full_trace,
                  :started_at, :completed_at, :job_id, :workflow_execution_id

    def initialize(attributes = {})
      @id = attributes[:id]
      @workflow_class_name = attributes[:workflow_class_name]
      @status = attributes[:status] || 'pending'
      @initial_context = attributes[:initial_context] || {}
      @final_output = attributes[:final_output] || {}
      @error = attributes[:error]
      @failed_task_name = attributes[:failed_task_name]
      @full_trace = attributes[:full_trace] || []
      @started_at = attributes[:started_at]
      @completed_at = attributes[:completed_at]
      @job_id = attributes[:job_id]
      @workflow_execution_id = attributes[:workflow_execution_id]
    end

    # Create a new execution record
    def self.create!(attributes)
      if defined?(SuperAgent::ExecutionModel) && SuperAgent::ExecutionModel.respond_to?(:create_from_context)
        model = SuperAgent::ExecutionModel.create_from_context(
          attributes[:workflow_class_name], 
          attributes[:initial_context] || {},
          job_id: attributes[:job_id]
        )
        new(attributes.merge(
          workflow_execution_id: SecureRandom.uuid,
          job_id: attributes[:job_id]
        ))
      else
        new(attributes.merge(workflow_execution_id: SecureRandom.uuid))
      end
    end

    # Find an execution by workflow execution ID
    def self.find_by_workflow_execution_id(workflow_execution_id)
      return nil unless defined?(SuperAgent::ExecutionModel)
      
      model = SuperAgent::ExecutionModel.find_by(workflow_execution_id: workflow_execution_id)
      return nil unless model
      
      new(model.attributes.symbolize_keys)
    end

    # Update the execution with result data
    def update_with_result(result)
      if defined?(SuperAgent::ExecutionModel) && workflow_execution_id
        model = SuperAgent::ExecutionModel.find_by(workflow_execution_id: workflow_execution_id)
        model.update_from_result(result) if model
      else
        @status = result.status
        @final_output = result.final_output
        @error = result.error
        @failed_task_name = result.failed_task_name
        @full_trace = result.full_trace
        @completed_at = Time.now
      end
    end

    # Mark as started
    def start!
      if defined?(SuperAgent::ExecutionModel) && workflow_execution_id
        model = SuperAgent::ExecutionModel.find_by(workflow_execution_id: workflow_execution_id)
        model.start! if model
      else
        @started_at = Time.now
      end
    end

    # Save the execution (stub for now)
    def save!
      true
    end

    # Check if execution is completed
    def completed?
      %w[completed failed].include?(@status)
    end

    # Check if execution failed
    def failed?
      @status == 'failed'
    end

    # Duration in milliseconds
    def duration_ms
      return nil unless started_at && completed_at
      ((completed_at - started_at) * 1000).to_i
    end
  end
end