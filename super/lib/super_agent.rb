# frozen_string_literal: true

require "zeitwerk"
require "dry/struct"
require "dry/types"
require "active_support"

# Try to load ActiveJob, but don't fail if not available
begin
  require "active_job"
rescue LoadError
  # Define a minimal ActiveJob for standalone usage
  module ActiveJob
    class Base
      def self.perform_later(*args)
        # Fallback to synchronous execution if ActiveJob not available
        new.perform(*args)
      end
    end
  end
end

# Zeitwerk setup for automatic loading
loader = Zeitwerk::Loader.for_gem
loader.ignore("#{__dir__}/generators")
loader.setup

module SuperAgent
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class WorkflowError < Error; end
  class TaskError < Error; end

  # Main configuration method for the gem
  def self.configure
    yield(configuration)
  end

  # Access the global configuration
  def self.configuration
    @configuration ||= Configuration.new
  end

  # Reset configuration (mainly for testing)
  def self.reset_configuration
    @configuration = nil
  end

  # Convenience method to check if a provider is available
  def self.provider_available?(provider)
    case provider
    when :openai
      defined?(OpenAI)
    when :open_router
      defined?(OpenRouter)
    when :anthropic
      defined?(Anthropic)
    else
      false
    end
  end

  # Get current provider status
  def self.provider_status
    {
      current: configuration.llm_provider,
      configured: configuration.provider_configured?,
      available_providers: [:openai, :open_router, :anthropic].select { |p| provider_available?(p) }
    }
  end

  # Check if Rails is available
  def self.rails_available?
    defined?(Rails) && Rails.respond_to?(:application)
  end
end

# Load essential files
require_relative "super_agent/step_result"
require_relative "super_agent/workflow_helpers"

# Load LLM interface
require_relative "super_agent/llm_interface"

# Conditionally load Rails-specific components
if defined?(Rails)
  begin
    require_relative "super_agent/execution_model"
    
    # Add WorkflowHelpers to ApplicationWorkflow if it exists
    Rails.application.config.to_prepare do
      if defined?(ApplicationWorkflow)
        ApplicationWorkflow.include SuperAgent::WorkflowHelpers
      end
    end
  rescue => e
    # Rails components failed to load, continue without them
    warn "Warning: Rails-specific components failed to load: #{e.message}"
  end
end
