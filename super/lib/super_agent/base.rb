# frozen_string_literal: true

require 'json'

module SuperAgent
  # Base class for AI agents, providing integration between Rails controllers and workflow engines
  #
  # This class serves as the bridge between Rails applications and the SuperAgent workflow
  # orchestration system. It provides a clean interface for running workflows while handling
  # context creation, security, and Rails integration.
  #
  # @example Basic usage in a controller
  #   class LeadAgent < SuperAgent::Base
  #     def analyze_lead(lead_data)
  #       result = run_workflow(LeadAnalysisWorkflow, initial_input: lead_data)
  #       
  #       if result.completed?
  #         render json: { analysis: result.final_output }
  #       else
  #         render json: { error: result.error_message }, status: 422
  #       end
  #     end
  #   end
  #
  class Base
    attr_reader :context, :params, :current_user, :request

    # Initialize a new agent instance
    #
    # @param context [Hash] Additional context data to merge with agent context
    # @param current_user [Object] The current authenticated user
    # @param request [ActionDispatch::Request] The current HTTP request
    # @param params [ActionController::Parameters] The request parameters
    def initialize(context: {}, current_user: nil, request: nil, params: {})
      @context = context
      @current_user = current_user
      @request = request
      @params = params
    end

    # Run a workflow synchronously
    #
    # @param workflow_class [Class] The workflow class to execute
    # @param initial_input [Hash] Initial input data for the workflow
    # @param streaming [Boolean] Whether to enable streaming mode
    # @param block [Proc] Optional block for streaming updates
    # @return [SuperAgent::WorkflowResult] The workflow execution result
    def run_workflow(workflow_class, initial_input: {}, streaming: false, &block)
      workflow_context = create_workflow_context(initial_input)
      engine = SuperAgent::WorkflowEngine.new
      
      if streaming && block_given?
        engine.execute(workflow_class, workflow_context, &block)
      else
        engine.execute(workflow_class, workflow_context)
      end
    end

    # Run a workflow asynchronously via ActiveJob
    #
    # @param workflow_class [Class] The workflow class to execute
    # @param initial_input [Hash] Initial input data for the workflow
    # @return [ActiveJob::Base] The enqueued job
    def run_workflow_later(workflow_class, initial_input: {})
      workflow_context = create_workflow_context(initial_input)
      SuperAgent::WorkflowJob.perform_later(workflow_class.name, workflow_context.to_h)
    end

    # Helper method to access agent context
    #
    # @return [Hash] The agent context including user and request info
    def agent_context
      {
        current_user_id: current_user&.id,
        current_user_type: current_user&.class&.name,
        request_id: request&.request_id,
        remote_ip: request&.remote_ip,
        user_agent: request&.user_agent,
        session_id: request&.session&.id
      }.compact
    end

    private

    # Create a safe workflow context by merging agent context with initial input
    #
    # @param initial_input [Hash] The initial input data
    # @return [SuperAgent::Workflow::Context] The created context
    def create_workflow_context(initial_input)
      # Merge contexts with proper precedence: initial_input > agent_context > context
      merged_data = agent_context.merge(context).merge(initial_input)
      
      # Prepare for ActiveJob serialization
      serialized_data = serialize_for_activejob(merged_data)
      
      # Validate serializability
      validate_serializable(serialized_data)
      
      # Filter out sensitive data
      filtered_data = filter_sensitive_data(serialized_data)
      
      SuperAgent::Workflow::Context.new(**filtered_data)
    end

    # Filter sensitive data from context
    #
    # @param data [Hash] The data to filter
    # @return [Hash] Filtered data
    def filter_sensitive_data(data)
      sensitive_keys = SuperAgent.configuration.sensitive_log_filter || []
      
      data.each_with_object({}) do |(key, value), filtered|
        key_sym = key.to_sym
        if should_filter_key?(key_sym, value, sensitive_keys)
          filtered[key_sym] = "[FILTERED]"
        else
          filtered[key_sym] = value
        end
      end
    end

    # Determine if a key should be filtered
    #
    # @param key [Symbol, String] The key to check
    # @param value [Object] The value to check
    # @param sensitive_keys [Array] List of sensitive keys or procs
    # @return [Boolean] Whether to filter the key
    def should_filter_key?(key, value, sensitive_keys)
      key_str = key.to_s
      
      sensitive_keys.any? do |filter|
        case filter
        when String, Symbol
          key_str.downcase.include?(filter.to_s.downcase)
        when Regexp
          key_str.match?(filter)
        when Proc
          filter.call(key, value)
        else
          false
        end
      end
    end

    # Validate that data is serializable and prepare for ActiveJob
    #
    # @param data [Object] The data to validate
    # @raise [ArgumentError] If data is not serializable
    def validate_serializable(data)
      serialized = serialize_for_activejob(data)
      JSON.generate(serialized, allow_nan: false)
    rescue JSON::GeneratorError, TypeError => e
      raise ArgumentError, "Data must be JSON serializable: #{e.message}"
    rescue NoMethodError => e
      raise ArgumentError, "Data contains non-serializable objects: #{e.message}"
    end

    # Serialize data for ActiveJob with GlobalID support
    #
    # @param data [Object] The data to serialize
    # @return [Hash] Serialized data ready for ActiveJob
    def serialize_for_activejob(data)
      case data
      when Hash
        data.each_with_object({}) do |(key, value), hash|
          hash[key] = serialize_for_activejob(value)
        end
      when Array
        data.map { |item| serialize_for_activejob(item) }
      else
        if defined?(ActiveRecord::Base) && data.is_a?(ActiveRecord::Base)
          data.to_global_id.to_s
        else
          data
        end
      end
    end

    # Simple LLM completion using the implicit single-step workflow
    # 
    # @param prompt [String, Array] The prompt or messages for the LLM
    # @param options [Hash] Additional options like model, temperature, etc.
    # @return [SuperAgent::WorkflowResult] The workflow execution result
    def generate_now(prompt = nil, **options)
      prompt ||= @context[:prompt] || @context[:messages]
      
      context_data = {
        prompt: prompt,
        model: options[:model] || SuperAgent.configuration.default_llm_model,
        temperature: options[:temperature] || 0.7,
        max_tokens: options[:max_tokens]
      }.merge(options).compact

      run_workflow(SuperAgent::Workflows::SingleStep::LlmWorkflow, initial_input: context_data)
    end

    # Simple LLM completion using the implicit single-step workflow (async)
    # 
    # @param prompt [String, Array] The prompt or messages for the LLM
    # @param options [Hash] Additional options like model, temperature, etc.
    # @return [ActiveJob::Base] The enqueued job
    def generate_later(prompt = nil, **options)
      prompt ||= @context[:prompt] || @context[:messages]
      
      context_data = {
        prompt: prompt,
        model: options[:model] || SuperAgent.configuration.default_llm_model,
        temperature: options[:temperature] || 0.7,
        max_tokens: options[:max_tokens]
      }.merge(options).compact

      run_workflow_later(SuperAgent::Workflows::SingleStep::LlmWorkflow, initial_input: context_data)
    end

    # DSL for setting up prompts and context (ActiveAgent compatibility)
    def prompt(messages = nil, **options)
      if messages
        @context = @context.merge(options).merge(prompt: messages)
        self
      else
        @context[:prompt] || @context[:messages]
      end
    end

    # DSL for setting context variables (ActiveAgent compatibility)
    def with(params = {})
      @context = @context.merge(params)
      self
    end

    # DSL for setting generation options (ActiveAgent compatibility)
    def generate_with(**options)
      @context = @context.merge(options)
      self
    end

    # Alias for generate_now for ActiveAgent compatibility
    alias_method :generate, :generate_now

    private

    # Create context specifically for simple LLM interactions
    def create_simple_llm_context(prompt, options = {})
      base_context = {
        current_user_id: current_user&.id,
        current_user_type: current_user&.class&.name
      }.compact

      base_context.merge(
        prompt: prompt,
        **options
      )
    end
  end
end