# frozen_string_literal: true

require 'json'

module SuperAgent
  module A2A
    module Utils
      # JSON validator for A2A protocol compliance
      class JsonValidator
      class << self
        def validate_agent_card(data)
          errors = []

          # Required fields
          required_fields = %w[id name version serviceEndpointURL capabilities]
          required_fields.each do |field|
            errors << "Missing required field: #{field}" unless data.key?(field)
          end

          # Validate URL format
          if data['serviceEndpointURL']
            begin
              URI.parse(data['serviceEndpointURL'])
            rescue URI::InvalidURIError
              errors << 'Invalid serviceEndpointURL format'
            end
          end

          # Validate capabilities structure
          if data['capabilities']
            if data['capabilities'].is_a?(Array)
              data['capabilities'].each_with_index do |capability, index|
                capability_errors = validate_capability(capability, index)
                errors.concat(capability_errors)
              end
            else
              errors << 'capabilities must be an array'
            end
          end

          errors
        end

        def validate_capability(capability, index = nil)
          errors = []
          prefix = index ? "capabilities[#{index}]" : 'capability'

          # Required capability fields
          required_fields = %w[name description]
          required_fields.each do |field|
            unless capability.key?(field) && capability[field].present?
              errors << "#{prefix}: Missing required field: #{field}"
            end
          end

          # Validate parameters structure if present
          if capability['parameters'] && !capability['parameters'].is_a?(Hash)
            errors << "#{prefix}: parameters must be an object"
          end

          # Validate returns structure if present
          if capability['returns'] && !capability['returns'].is_a?(Hash)
            errors << "#{prefix}: returns must be an object"
          end

          errors
        end

        def validate_jsonrpc_request(data)
          errors = []

          # Check JSON-RPC version
          errors << "Invalid or missing JSON-RPC version (must be '2.0')" unless data['jsonrpc'] == '2.0'

          # Check method
          errors << 'Missing required field: method' unless data['method'].present?

          # Check ID (can be string, number, or null, but not missing)
          errors << 'Missing required field: id' unless data.key?('id')

          # Validate invoke method specific requirements
          errors.concat(validate_invoke_params(data['params'])) if data['method'] == 'invoke'

          errors
        end

        def validate_invoke_params(params)
          errors = []

          unless params.is_a?(Hash)
            errors << 'params must be an object'
            return errors
          end

          unless params['task'].is_a?(Hash)
            errors << 'params.task must be an object'
            return errors
          end

          task = params['task']

          # Required task fields
          errors << 'params.task.skill is required' unless task['skill'].present?

          # Validate parameters if present
          errors << 'params.task.parameters must be an object' if task['parameters'] && !task['parameters'].is_a?(Hash)

          errors
        end

        def validate_sse_event(event_data)
          errors = []

          unless event_data.is_a?(Hash)
            errors << 'SSE event data must be an object'
            return errors
          end

          # Common event types and their requirements
          case event_data['event']
          when 'start'
            errors << 'start event must include data.status' unless event_data['data'] && event_data['data']['status']
          when 'complete'
            unless event_data['data'] && event_data['data']['status']
              errors << 'complete event must include data.status'
            end
          when 'error'
            errors << 'error event must include data.error' unless event_data['data'] && event_data['data']['error']
          end

          errors
        end
      end
    end
  end
end
