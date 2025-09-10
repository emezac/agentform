# frozen_string_literal: true

module SuperAgent
  # Value object representing the result of a workflow execution
  class WorkflowResult
    attr_reader :status, :error, :failed_task_name, :failed_task_error,
                :final_output, :full_trace, :workflow_execution_id, :duration_ms

    def initialize(status:, error: nil, failed_task_name: nil, failed_task_error: nil,
                   final_output: nil, full_trace: [], workflow_execution_id: nil, duration_ms: nil)
      @status = status.to_sym
      @error = error
      @failed_task_name = failed_task_name
      @failed_task_error = failed_task_error
      @final_output = final_output
      @full_trace = full_trace
      @workflow_execution_id = workflow_execution_id
      @duration_ms = duration_ms
    end

    # Check if workflow completed successfully
    def completed?
      status == :completed
    end

    # Alias for completed? for compatibility
    def success?
      completed?
    end

    # Check if workflow failed
    def failed?
      status == :failed
    end

    # Get output for a specific step
    def output_for(step_name)
      return nil if step_name.nil?
      step = full_trace.find { |s| s[:step_name] == step_name.to_sym }
      step&.dig(:output)
    end

    # Get all outputs
    def outputs
      full_trace.each_with_object({}) do |step, hash|
        hash[step[:step_name]] = step[:output]
      end
    end

    # Get error message (safe for user display)
    def error_message
      return nil unless failed?

      if failed_task_error
        "Failed at task '#{failed_task_name}': #{failed_task_error}"
      else
        "Workflow failed: #{error}"
      end
    end

    # Human-readable summary
    def summary
      if completed?
        "Workflow completed successfully in #{duration_ms}ms"
      else
        error_message
      end
    end

    # Convert to hash for JSON serialization
    def to_h
      {
        status: status,
        error: error,
        failed_task_name: failed_task_name,
        failed_task_error: failed_task_error,
        final_output: final_output,
        full_trace: full_trace,
        workflow_execution_id: workflow_execution_id,
        duration_ms: duration_ms
      }
    end

    # Create a success result
    def self.success(final_output:, full_trace:, workflow_execution_id:, duration_ms:)
      new(
        status: :completed,
        final_output: final_output,
        full_trace: full_trace,
        workflow_execution_id: workflow_execution_id,
        duration_ms: duration_ms
      )
    end

    # Create a failure result
    def self.failure(error:, failed_task_name:, failed_task_error:, full_trace:, workflow_execution_id:, duration_ms:)
      new(
        status: :failed,
        error: error,
        failed_task_name: failed_task_name,
        failed_task_error: failed_task_error,
        full_trace: full_trace,
        workflow_execution_id: workflow_execution_id,
        duration_ms: duration_ms
      )
    end
  end
end