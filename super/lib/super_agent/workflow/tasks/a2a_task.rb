# frozen_string_literal: true

require 'securerandom'

module SuperAgent
  module Workflow
    module Tasks
      # Task for invoking external A2A-compatible agents from within SuperAgent workflows
      class A2aTask < Task
        attr_reader :agent_url, :skill_name, :timeout, :auth_config, :stream, :webhook_url, :client

        def initialize(name, config = {})
          super

          @agent_url = config[:agent_url]
          @skill_name = config[:skill]
          @timeout = config[:timeout] || SuperAgent.configuration.a2a_default_timeout
          @auth_config = config[:auth]
          @stream = config[:stream] || false
          @webhook_url = config[:webhook_url]
          @fail_on_error = config[:fail_on_error] != false # Default to true
          @input_keys = Array(config[:input] || config[:inputs] || [])
          @output_key = config[:output]
          @client = nil

          validate_configuration!
        end

        def execute(context)
          log_start(context)
          start_time = Time.current

          @client = build_client
          validate_prerequisites!

          parameters = extract_parameters(context)
          request_id = SecureRandom.uuid

          log_info("Invoking A2A skill '#{@skill_name}' on #{@agent_url}")

          result = if @stream
                     handle_streaming_execution(parameters, context, request_id)
                   else
                     handle_blocking_execution(parameters, context, request_id)
                   end

          duration_ms = ((Time.current - start_time) * 1000).round(2)
          log_complete(context, result, duration_ms)

          result
        rescue SuperAgent::A2A::Error => e
          duration_ms = ((Time.current - start_time) * 1000).round(2) if start_time
          log_error(context, e)
          handle_error(e.message, context)
        rescue StandardError => e
          duration_ms = ((Time.current - start_time) * 1000).round(2) if start_time
          log_error(context, e)
          handle_error("Unexpected error: #{e.message}", context)
        end

        def validate!
          super
          validate_configuration!
        end

        def description
          "A2A task: Invoke '#{@skill_name}' skill on #{@agent_url}"
        end

        def required_inputs
          @input_keys.any? ? @input_keys : [:*] # Dynamic inputs
        end

        def provided_outputs
          @output_key ? [@output_key] : [:a2a_result]
        end

        private

        def validate_configuration!
          raise ArgumentError, 'agent_url is required' unless @agent_url
          raise ArgumentError, 'skill is required' unless @skill_name
          raise ArgumentError, 'timeout must be positive' unless @timeout > 0

          # Validate URL format
          begin
            URI.parse(@agent_url)
          rescue URI::InvalidURIError
            raise ArgumentError, "Invalid agent_url format: #{@agent_url}"
          end
        end

        def build_client
          auth_token = resolve_auth_token
          max_retries = config[:max_retries] || config[:retries] || SuperAgent.configuration.a2a_max_retries
          cache_ttl = config[:cache_ttl] || SuperAgent.configuration.a2a_cache_ttl

          SuperAgent::A2A::Client.new(
            @agent_url,
            auth_token: auth_token,
            timeout: @timeout,
            max_retries: max_retries,
            cache_ttl: cache_ttl
          )
        end

        def resolve_auth_token
          return nil unless @auth_config

          case @auth_config
          when String
            @auth_config
          when Hash
            case @auth_config[:type]
            when :env
              ENV.fetch(@auth_config[:key], nil)
            when :config
              SuperAgent.configuration.public_send(@auth_config[:key])
            when :proc
              @auth_config[:proc].call if @auth_config[:proc].respond_to?(:call)
            else
              @auth_config
            end
          when Proc
            @auth_config.call
          else
            @auth_config.to_s
          end
        end

        def validate_prerequisites!
          # Check if agent is reachable
          raise SuperAgent::A2A::NetworkError, "Agent at #{@agent_url} is not reachable" unless @client.health_check

          # Validate skill exists
          return if @client.supports_skill?(@skill_name)

          capabilities = @client.list_capabilities.map(&:name).join(', ')
          raise SuperAgent::A2A::SkillNotFoundError,
                "Skill '#{@skill_name}' not available. Available skills: #{capabilities}"
        end

        def extract_parameters(context)
          if @input_keys.any?
            @input_keys.each_with_object({}) do |key, params|
              value = context.get(key)
              params[key.to_s] = value unless value.nil?
            end
          else
            # Pass all context except internal A2A keys
            context.to_h.except(:_a2a_skill, :_a2a_request_id, :_a2a_timestamp)
          end
        end

        def handle_blocking_execution(parameters, context, request_id)
          result = @client.invoke_skill(@skill_name, parameters,
                                        request_id: request_id,
                                        webhook_url: @webhook_url)

          process_result(result, context)
        end

        def handle_streaming_execution(parameters, context, request_id)
          results = []
          errors = []

          @client.invoke_skill(@skill_name, parameters,
                               request_id: request_id,
                               stream: true,
                               webhook_url: @webhook_url) do |event|
            log_debug("Streaming event: #{event}")

            case event[:event]
            when 'task_complete', 'complete'
              results << event[:data]['result'] if event[:data] && event[:data]['result']
            when 'error'
              error_msg = event[:data]['error'] || 'Unknown streaming error'
              errors << error_msg
            end
          end

          # Handle any errors that occurred during streaming
          if errors.any?
            raise SuperAgent::A2A::InvocationError,
                  "Streaming errors: #{errors.join(', ')}"
          end

          # Combine streaming results
          combined_result = results.reduce({}) { |acc, result| acc.merge(result) }
          process_result({ 'result' => combined_result, 'status' => 'completed' }, context)
        end

        def process_result(result, context)
          if result['status'] == 'completed' || result['result']
            # Extract main result
            main_result = result['result'] || result

            # Process artifacts if present
            process_artifacts(result['artifacts'], context) if result['artifacts']&.any?

            # Store result in context
            if @output_key
              context.set(@output_key, main_result)
            elsif main_result.is_a?(Hash)
              # Merge result into context if it's a hash
              main_result.each { |k, v| context.set(k, v) }
            else
              context.set(:a2a_result, main_result)
            end

            log_info('A2A task completed successfully')
            main_result
          else
            error_msg = result['error'] || 'Unknown error from A2A agent'
            raise SuperAgent::A2A::InvocationError, error_msg
          end
        end

        def process_artifacts(artifacts, context)
          artifacts.each_with_index do |artifact_data, index|
            artifact = SuperAgent::A2A::Artifact.from_hash(artifact_data)

            # Store artifact in context with meaningful key
            artifact_key = if artifact.name.present?
                             "#{@name}_#{artifact.name}"
                           else
                             "#{@name}_artifact_#{index}"
                           end

            context.set(artifact_key, artifact)

            # For document artifacts, also store the content directly
            if artifact.is_a?(SuperAgent::A2A::DocumentArtifact)
              context.set("#{artifact_key}_content", artifact.content)
            elsif artifact.is_a?(SuperAgent::A2A::DataArtifact)
              context.set("#{artifact_key}_data", artifact.parsed_content)
            end

            log_debug("Processed artifact: #{artifact_key}")
          rescue StandardError => e
            log_warn("Failed to process artifact #{index}: #{e.message}")
          end
        end

        def handle_error(message, context)
          if @fail_on_error
            context.set(:error, message)
            raise SuperAgent::Workflow::TaskError, message
          else
            log_warn("A2A task failed but continuing: #{message}")
            output_key = @output_key || :a2a_error
            context.set(output_key, { error: message, timestamp: Time.current.iso8601 })
            { error: message, failed: true }
          end
        end

        def log_info(message)
          return unless defined?(SuperAgent.configuration.logger)

          SuperAgent.configuration.logger.info("A2ATask[#{@name}]: #{message}")
        end

        def log_warn(message)
          return unless defined?(SuperAgent.configuration.logger)

          SuperAgent.configuration.logger.warn("A2ATask[#{@name}]: #{message}")
        end

        def log_debug(message)
          return unless defined?(SuperAgent.configuration.logger)

          SuperAgent.configuration.logger.debug("A2ATask[#{@name}]: #{message}")
        end

        def log_start(context)
          log_info("Starting A2A task: #{@skill_name} on #{@agent_url}")
          return unless defined?(SuperAgent.configuration.logger)

          SuperAgent.configuration.logger.info(
            "Starting A2A task #{name}",
            task: name,
            agent_url: @agent_url,
            skill: @skill_name,
            stream: @stream,
            context_keys: context.to_h.keys
          )
        end

        def log_complete(context, result, duration_ms)
          log_info("Completed A2A task in #{duration_ms}ms")
          return unless defined?(SuperAgent.configuration.logger)

          SuperAgent.configuration.logger.info(
            "Completed A2A task #{name}",
            task: name,
            duration_ms: duration_ms,
            success: true
          )
        end

        def log_error(context, error)
          log_warn("A2A task failed: #{error.message}")
          return unless defined?(SuperAgent.configuration.logger)

          SuperAgent.configuration.logger.error(
            "Failed A2A task #{name}",
            task: name,
            error: error.message,
            error_class: error.class.name,
            agent_url: @agent_url,
            skill: @skill_name
          )
        end
      end
    end
  end
end
