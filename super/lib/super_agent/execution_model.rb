# frozen_string_literal: true

module SuperAgent
  # ActiveRecord model for tracking workflow executions
  # This provides full persistence for async workflows in Rails applications
  if defined?(ActiveRecord)
    class ExecutionModel < ActiveRecord::Base
      self.table_name = 'super_agent_executions'

      # Validations
      validates :workflow_class_name, presence: true
      validates :status, inclusion: { in: %w[pending running completed failed] }
      validates :workflow_execution_id, presence: true, uniqueness: true

      # Scopes
      scope :pending, -> { where(status: 'pending') }
      scope :running, -> { where(status: 'running') }
      scope :completed, -> { where(status: 'completed') }
      scope :failed, -> { where(status: 'failed') }
      scope :recent, -> { order(created_at: :desc) }

      # Status methods
      def pending?
        status == 'pending'
      end

      def running?
        status == 'running'
      end

      def completed?
        status == 'completed'
      end

      def failed?
        status == 'failed'
      end

      # Duration helpers
      def duration_ms
        return nil unless started_at && completed_at
        ((completed_at - started_at) * 1000).to_i
      end

      def running_duration_ms
        return nil unless started_at && running?
        ((Time.now - started_at) * 1000).to_i
      end

      # JSON helpers
      def initial_context_hash
        initial_context.is_a?(String) ? JSON.parse(initial_context) : initial_context
      end

      def final_output_hash
        final_output.is_a?(String) ? JSON.parse(final_output) : final_output
      end

      def full_trace_array
        full_trace.is_a?(String) ? JSON.parse(full_trace) : full_trace
      end

      # Update from workflow result
      def update_from_result(result)
        self.status = result.status
        self.final_output = result.final_output
        self.error = result.error
        self.failed_task_name = result.failed_task_name
        self.full_trace = result.full_trace
        self.completed_at = Time.now
        save!
      end

      # Start execution
      def start!
        self.status = 'running'
        self.started_at = Time.now
        save!
      end

      # Create from workflow context
      def self.create_from_context(workflow_class_name, context_data, job_id: nil)
        create!(
          workflow_class_name: workflow_class_name,
          initial_context: context_data,
          job_id: job_id,
          workflow_execution_id: SecureRandom.uuid,
          status: 'pending'
        )
      end
    end
  else
    # Stub class for non-Rails environments
    class ExecutionModel
      def self.create_from_context(*args)
        nil
      end

      def self.find_by(*args)
        nil
      end

      def update_from_result(*args)
        true
      end

      def start!
        true
      end

      def self.create!(*args)
        nil
      end
    end
  end
end