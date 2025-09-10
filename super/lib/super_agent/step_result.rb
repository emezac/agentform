# frozen_string_literal: true

module SuperAgent
  # Represents the result of a single step in a workflow, used for streaming updates
  class StepResult
    attr_reader :step_name, :status, :output, :duration_ms, :timestamp, :workflow_execution_id

    # @param step_name [String] The name of the step
    # @param status [Symbol] The status of the step (:success, :failed, :skipped)
    # @param output [Hash] The output data from the step
    # @param duration_ms [Integer] Duration in milliseconds
    # @param timestamp [String] ISO8601 timestamp
    # @param workflow_execution_id [String] Unique workflow execution ID
    def initialize(step_name:, status:, output: {}, duration_ms:, timestamp:, workflow_execution_id:)
      @step_name = step_name
      @status = status
      @output = output
      @duration_ms = duration_ms
      @timestamp = timestamp
      @workflow_execution_id = workflow_execution_id
    end

    # Convert to hash representation
    # @return [Hash] Hash representation of the step result
    def to_h
      {
        step_name: step_name,
        status: status,
        output: output,
        duration_ms: duration_ms,
        timestamp: timestamp,
        workflow_execution_id: workflow_execution_id
      }
    end

    # Check if step was successful
    # @return [Boolean] true if step completed successfully
    def success?
      status == :success
    end

    # Check if step failed
    # @return [Boolean] true if step failed
    def failed?
      status == :failed
    end

    # Check if step was skipped
    # @return [Boolean] true if step was skipped
    def skipped?
      status == :skipped
    end
  end
end