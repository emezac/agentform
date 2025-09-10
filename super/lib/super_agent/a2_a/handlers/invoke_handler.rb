# frozen_string_literal: true

require 'json'
require 'rack'

module SuperAgent
  module A2A
    module Handlers
      # Handler for skill invocation endpoint (/invoke)
      class InvokeHandler
      def initialize(workflow_registry)
        @workflow_registry = workflow_registry
      end

      def call(env)
        request = Rack::Request.new(env)

        return method_not_allowed unless request.post?

        begin
          content_type = request.get_header('CONTENT_TYPE')
          accept_header = request.get_header('HTTP_ACCEPT')

          if accept_header&.include?('text/event-stream')
            handle_streaming_request(request)
          else
            handle_blocking_request(request)
          end
        rescue JSON::ParserError => e
          log_error("Invalid JSON payload: #{e.message}")
          bad_request("Invalid JSON payload: #{e.message}")
        rescue ValidationError => e
          log_error("Validation error: #{e.message}")
          bad_request(e.message)
        rescue StandardError => e
          log_error("Unexpected error in invoke handler: #{e.message}")
          log_error(e.backtrace.join("\n"))
          internal_error('Internal server error')
        end
      end

      private

      def handle_blocking_request(request)
        payload = parse_request_payload(request)
        jsonrpc_request = validate_jsonrpc_request(payload)

        task_params = jsonrpc_request['params']['task']
        skill_name = task_params['skill']
        parameters = task_params['parameters'] || {}
        request_id = task_params['id'] || jsonrpc_request['id']

        # Find appropriate workflow
        workflow_class = find_workflow_for_skill(skill_name)
        raise ValidationError, "Skill '#{skill_name}' not found" unless workflow_class

        # Execute workflow
        context = build_context_from_parameters(parameters, skill_name, request_id)
        result = execute_workflow(workflow_class, context)

        # Format response
        response_data = format_jsonrpc_response(jsonrpc_request['id'], result)

        [200,
         { 'Content-Type' => 'application/json' },
         [response_data.to_json],]
      end

      def handle_streaming_request(request)
        payload = parse_request_payload(request)
        jsonrpc_request = validate_jsonrpc_request(payload)

        task_params = jsonrpc_request['params']['task']
        skill_name = task_params['skill']
        parameters = task_params['parameters'] || {}
        request_id = task_params['id'] || jsonrpc_request['id']

        # Find appropriate workflow
        workflow_class = find_workflow_for_skill(skill_name)
        raise ValidationError, "Skill '#{skill_name}' not found" unless workflow_class

        [200,
         { 'Content-Type' => 'text/event-stream', 'Cache-Control' => 'no-cache' },
         StreamingEnumerator.new(workflow_class, parameters, skill_name, request_id),]
      end

      def parse_request_payload(request)
        body = request.body.read
        request.body.rewind
        JSON.parse(body)
      end

      def validate_jsonrpc_request(payload)
        raise ValidationError, "Invalid JSON-RPC version (must be '2.0')" unless payload['jsonrpc'] == '2.0'

        unless payload['method'] == 'invoke'
          raise ValidationError, "Invalid method: #{payload['method']} (must be 'invoke')"
        end

        unless payload['params'] && payload['params']['task']
          raise ValidationError, 'Missing task parameters in request'
        end

        raise ValidationError, 'Missing request ID' unless payload.key?('id')

        payload
      end

      def find_workflow_for_skill(skill_name)
        # First try exact match on task names
        @workflow_registry.values.find do |workflow_class|
          workflow_class.workflow_definition.tasks.any? { |task| task.name.to_s == skill_name }
        end
      end

      def build_context_from_parameters(parameters, skill_name, request_id)
        # Create a new context with the provided parameters
        context_data = parameters.is_a?(Hash) ? parameters : {}
        context = SuperAgent::Workflow::Context.new(context_data)

        # Add A2A metadata
        context.set(:_a2a_skill, skill_name)
        context.set(:_a2a_request_id, request_id)
        context.set(:_a2a_timestamp, Time.current.iso8601)

        context
      end

      def execute_workflow(workflow_class, context)
        # Check if SuperAgent::WorkflowEngine exists, fallback to basic execution
        if defined?(SuperAgent::WorkflowEngine)
          engine = SuperAgent::WorkflowEngine.new
          execution_result = engine.execute(workflow_class, context)
        else
          # Fallback execution for basic workflows
          execution_result = execute_workflow_basic(workflow_class, context)
        end

        if execution_result.respond_to?(:failed?) && execution_result.failed?
          error_message = if execution_result.respond_to?(:error_message)
                            execution_result.error_message
                          else
                            'Workflow execution failed'
                          end
          raise InvocationError, "Workflow execution failed: #{error_message}"
        end

        # Convert result to A2A format
        final_context = if execution_result.respond_to?(:context)
                          execution_result.context
                        else
                          context
                        end

        {
          status: 'completed',
          result: final_context.to_h.except(:_a2a_skill, :_a2a_request_id, :_a2a_timestamp),
          artifacts: extract_artifacts(final_context),
          metadata: {
            workflow_class: workflow_class.name,
            execution_time: Time.current.iso8601,
            superagent_version: defined?(SuperAgent::VERSION) ? SuperAgent::VERSION : 'unknown',
          },
        }
      end

      def execute_workflow_basic(workflow_class, context)
        # Basic workflow execution fallback

        workflow_instance = workflow_class.new
        if workflow_instance.respond_to?(:execute)
          workflow_instance.execute(context)
        else
          context
        end
      rescue StandardError => e
        raise InvocationError, "Workflow execution error: #{e.message}"
      end

      def extract_artifacts(context)
        artifacts = []

        context.to_h.each do |key, value|
          case value
          when String
            if value.length > 1000 # Large text becomes document artifact
              artifacts << {
                id: SecureRandom.uuid,
                type: 'document',
                name: "#{key}_result",
                content: value,
                description: "Result from #{key}",
                size: value.bytesize,
                createdAt: Time.current.iso8601,
              }
            end
          when Hash, Array
            artifacts << {
              id: SecureRandom.uuid,
              type: 'data',
              name: "#{key}_data",
              content: value,
              description: "Data result from #{key}",
              encoding: 'json',
              size: value.to_json.bytesize,
              createdAt: Time.current.iso8601,
            }
          end
        end

        artifacts
      end

      def format_jsonrpc_response(id, result)
        {
          jsonrpc: '2.0',
          result: result,
          id: id,
        }
      end

      def method_not_allowed
        [405,
         {
           'Content-Type' => 'application/json',
           'Allow' => 'POST',
         },
         [{ 'error' => 'Method not allowed', 'allowed_methods' => ['POST'] }.to_json],]
      end

      def bad_request(message)
        [400,
         { 'Content-Type' => 'application/json' },
         [{ 'error' => message, 'code' => 'bad_request' }.to_json],]
      end

      def internal_error(message)
        [500,
         { 'Content-Type' => 'application/json' },
         [{ 'error' => message, 'code' => 'internal_error' }.to_json],]
      end

      def log_error(message)
        return unless defined?(SuperAgent.logger)

        SuperAgent.logger.error("InvokeHandler: #{message}")
      end

      def log_info(message)
        return unless defined?(SuperAgent.logger)

        SuperAgent.logger.info("InvokeHandler: #{message}")
      end
      end

      # Streaming enumerator for Server-Sent Events
      class StreamingEnumerator
      def initialize(workflow_class, parameters, skill_name, request_id)
        @workflow_class = workflow_class
        @parameters = parameters
        @skill_name = skill_name
        @request_id = request_id
      end

      def each
        yield "event: start\n"
        yield "data: #{{ 'status' => 'started', 'id' => @request_id }.to_json}\n\n"

        begin
          context_data = @parameters.is_a?(Hash) ? @parameters : {}
          context = SuperAgent::Workflow::Context.new(context_data)
          context.set(:_a2a_skill, @skill_name)
          context.set(:_a2a_request_id, @request_id)

          # Execute workflow with progress updates
          if defined?(SuperAgent::WorkflowEngine)
            engine = SuperAgent::WorkflowEngine.new

            # Hook into workflow execution for progress updates if supported
            if engine.respond_to?(:on_task_start)
              engine.on_task_start do |task|
                yield "event: task_start\n"
                yield "data: #{{ 'task' => task.name, 'status' => 'running' }.to_json}\n\n"
              end
            end

            if engine.respond_to?(:on_task_complete)
              engine.on_task_complete do |task, result|
                yield "event: task_complete\n"
                yield "data: #{{ 'task' => task.name, 'status' => 'completed', 'result' => result }.to_json}\n\n"
              end
            end

            execution_result = engine.execute(@workflow_class, context)
          else
            # Fallback execution
            execution_result = begin
              @workflow_class.new.execute(context)
            rescue StandardError
              context
            end
          end

          if execution_result.respond_to?(:completed?) && execution_result.completed?
            final_context = execution_result.respond_to?(:context) ? execution_result.context : context
            yield "event: complete\n"
            yield "data: #{{ 'status' => 'completed', 'result' => final_context.to_h }.to_json}\n\n"
          else
            error_message = execution_result.respond_to?(:error_message) ? execution_result.error_message : 'Execution failed'
            yield "event: error\n"
            yield "data: #{{ 'status' => 'failed', 'error' => error_message }.to_json}\n\n"
          end
        rescue StandardError => e
          log_error("Streaming execution error: #{e.message}")
          yield "event: error\n"
          yield "data: #{{ 'status' => 'failed', 'error' => e.message }.to_json}\n\n"
        end
      end

      private

      def log_error(message)
        return unless defined?(SuperAgent.logger)

        SuperAgent.logger.error("StreamingEnumerator: #{message}")
      end
      end
    end
  end
end
