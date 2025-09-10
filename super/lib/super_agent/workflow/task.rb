# frozen_string_literal: true

module SuperAgent
  module Workflow
    # Base class for all workflow tasks
    class Task
      attr_reader :name, :config

      def initialize(name, config = {})
        @name = name&.to_sym
        @config = config || {}
      end

      # Execute the task with the given context
      # @param context [Context] the current workflow context
      # @return [Object] the task result
      def execute(context)
        raise NotImplementedError, "#{self.class} must implement #execute"
      end

      # Validate task configuration
      def validate!
        true
      end

      # Task description for logging
      def description
        "#{self.class.name} task"
      end

      # Task timeout in seconds
      def timeout
        config[:timeout] || SuperAgent.configuration.default_llm_timeout
      end

      # Number of retries for this task
      def retries
        config[:retries] || SuperAgent.configuration.default_llm_retries
      end

      # Should this task be executed?
      def should_execute?(context)
        condition = config[:if]
        return true if condition.nil?

        if condition.respond_to?(:call)
          condition.call(context)
        else
          condition ? true : false
        end
      end

      private

      # Log task execution
      def log_start(context)
        SuperAgent.configuration.logger.info(
          "Starting task #{name}",
          task: name,
          context: context.filtered_for_logging
        )
      end

      def log_complete(context, result, duration_ms)
        SuperAgent.configuration.logger.info(
          "Completed task #{name}",
          task: name,
          duration_ms: duration_ms,
          result: result
        )
      end

      def log_error(context, error)
        SuperAgent.configuration.logger.error(
          "Failed task #{name}",
          task: name,
          error: error.message,
          error_class: error.class.name
        )
      end
    end
  end
end