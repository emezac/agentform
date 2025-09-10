# frozen_string_literal: true
# lib/super_agent/workflow_engine.rb

require 'securerandom'
require 'time'

module SuperAgent
  # Orchestrates workflow execution with comprehensive logging and error handling
  class WorkflowEngine
    attr_reader :logger

    def initialize
      @logger = SuperAgent.configuration.logger
    end

    # Execute a workflow with the given context
    # @param workflow_class [Class] the workflow class to execute
    # @param context [Workflow::Context] the initial context
    # @param block [Proc] optional block for streaming updates
    # @return [WorkflowResult] the execution result
    def execute(workflow_class, context, &block)
      workflow_execution_id = SecureRandom.uuid
      start_time = Time.now

      if logger.respond_to?(:info_hash)
        logger.info_hash(
          "Starting workflow execution",
          { workflow: workflow_class.name,
            workflow_execution_id: workflow_execution_id,
            initial_context: context.filtered_for_logging }
        )
      else
        logger.info("Starting workflow execution: #{workflow_class.name}")
      end

      workflow = workflow_class.new
      trace = []

      begin
        result = execute_steps(workflow, context, workflow_execution_id, trace, &block)
        duration_ms = ((Time.now - start_time) * 1000).round

        if logger.respond_to?(:info_hash)
          logger.info_hash(
            "Workflow execution completed",
            { workflow: workflow_class.name,
              workflow_execution_id: workflow_execution_id,
              duration_ms: duration_ms,
              status: :completed }
          )
        else
          logger.info("Workflow execution completed: #{workflow_class.name} (#{duration_ms}ms)")
        end

        WorkflowResult.success(
          final_output: extract_final_output(trace),
          full_trace: trace,
          workflow_execution_id: workflow_execution_id,
          duration_ms: duration_ms
        )

      rescue StandardError => e
        duration_ms = ((Time.now - start_time) * 1000).round
        
        if logger.respond_to?(:error_hash)
          logger.error_hash(
            "Workflow execution failed",
            { workflow: workflow_class.name,
              workflow_execution_id: workflow_execution_id,
              error: e.message,
              error_class: e.class.name,
              backtrace: e.backtrace.first(10),
              duration_ms: duration_ms }
          )
        else
          logger.error("Workflow execution failed: #{workflow_class.name} - #{e.message}")
        end

        WorkflowResult.failure(
          error: e.message,
          failed_task_name: @current_task_name,
          failed_task_error: e.message,
          full_trace: trace,
          workflow_execution_id: workflow_execution_id,
          duration_ms: duration_ms
        )
      end
    end

    private

    def execute_steps(workflow, context, workflow_execution_id, trace, &block)
      workflow.steps.each do |step_definition|
        step_name = step_definition[:name]
        step_config = step_definition[:config]
        
        @current_task_name = step_name
        
        # Create task instance
        task = create_task(step_name, step_config)
        
        # Check if task should execute
        next unless task.should_execute?(context)

        # Execute task with timing
        step_start = Time.now
        logger.info("Executing task: #{step_name}")

        begin
          result = task.execute(context)
          step_duration = ((Time.now - step_start) * 1000).round

          # Create step result
          step_result = {
            step_name: step_name,
            status: :success,
            output: result,
            duration_ms: step_duration,
            timestamp: Time.now.iso8601
          }

          trace << step_result

          # Update context with result
          context = context.set(step_name, result)

          # Stream progress if block provided
          block.call(step_result) if block_given?

          logger.info("Task completed: #{step_name} (#{step_duration}ms)")

        rescue StandardError => e
          step_duration = ((Time.now - step_start) * 1000).round
          
          step_result = {
            step_name: step_name,
            status: :failed,
            error: e.message,
            error_class: e.class.name,
            duration_ms: step_duration,
            timestamp: Time.now.iso8601
          }

          trace << step_result
          
          logger.error("Task failed: #{step_name} - #{e.message}")

          raise e
        end
      end

      context
    end

    def create_task(step_name, step_config)
      task_type = step_config[:uses]
      
      case task_type
      when :direct_handler
        SuperAgent::Workflow::DirectHandlerTask.new(step_name, step_config)
      when :llm, :llm_task
        # CORRECCIÓN CRÍTICA: Para tareas LLM del nuevo DSL, pasar toda la configuración
        # El nuevo DSL guarda prompt, model, etc. directamente en step_config, no en :with
        SuperAgent::Workflow::Tasks::LlmTask.new(step_name, step_config)
      when Symbol, String
        task_class = SuperAgent.configuration.tool_registry.get(task_type)
        raise ArgumentError, "Unknown task type: #{task_type}" unless task_class
        
        # Para otras tareas registradas, usar la configuración :with
        if task_class == SuperAgent::Workflow::Tasks::LlmTask
          # Si por alguna razón llega aquí una tarea LLM, usar configuración completa
          task_class.new(step_name, step_config)
        else
          # Para otras tareas, usar solo la parte :with
          task_class.new(step_name, step_config[:with] || {})
        end
      when nil
        raise ArgumentError, "No task type specified for step: #{step_name}"
      else
        task_class = step_config[:task_class] || step_config[:class]
        if task_class
          klass = task_class.is_a?(Class) ? task_class : task_class.constantize
          # Si es una tarea LLM personalizada, usar configuración completa
          if klass <= SuperAgent::Workflow::Tasks::LlmTask
            klass.new(step_name, step_config)
          else
            klass.new(step_name, step_config[:with] || {})
          end
        else
          raise ArgumentError, "No task type specified for step: #{step_name}"
        end
      end
    end

    def extract_final_output(trace)
      last_step = trace.last
      last_step&.dig(:output)
    end
  end
end
