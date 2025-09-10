# frozen_string_literal: true

module SuperAgent
  # Configuration class for SuperAgent gem
  class Configuration
    attr_accessor :llm_provider,
                  :openai_api_key, :openai_organization_id,
                  :anthropic_api_key,
                  :open_router_api_key, :open_router_site_name, :open_router_site_url,
                  :default_llm_model, :logger, :tool_registry,
                  :default_llm_timeout, :default_llm_retries, :sensitive_log_filter,
                  :workflows_dir, :agents_dir, :redis_url, :workflow_timeout,
                  :max_retries, :retry_delay, :log_level, :request_timeout,
                  :enable_instrumentation, :deprecation_warnings,
                  # A2A Protocol Configuration
                  :a2a_server_enabled, :a2a_server_port, :a2a_server_host,
                  :a2a_auth_token, :a2a_base_url, :a2a_ssl_cert_path,
                  :a2a_ssl_key_path, :a2a_default_timeout, :a2a_max_retries,
                  :a2a_cache_ttl, :a2a_user_agent, :a2a_agent_registry,
                  :a2a_auto_discovery_enabled

    def initialize
      # LLM Provider configuration
      @llm_provider = :openai # :openai, :open_router, :anthropic

      # OpenAI Configuration
      @openai_api_key = ENV.fetch('OPENAI_API_KEY', nil)
      @openai_organization_id = ENV.fetch('OPENAI_ORGANIZATION_ID', nil)

      # Anthropic Configuration
      @anthropic_api_key = ENV.fetch('ANTHROPIC_API_KEY', nil)

      # OpenRouter Configuration
      @open_router_api_key = ENV.fetch('OPENROUTER_API_KEY', nil)
      @open_router_site_name = nil
      @open_router_site_url = nil

      # Default LLM settings
      @default_llm_model = 'gpt-4'
      @default_llm_timeout = 30
      @default_llm_retries = 2

      # Logging configuration
      @logger = default_logger
      @log_level = :info
      @tool_registry = ToolRegistry.new

      # Security settings
      @sensitive_log_filter = [
        :password, :token, :secret, :key, :api_key, /password/i, /token/i, /secret/i, /api_key/i,
      ].freeze

      # Background job settings
      @workflows_dir = nil
      @agents_dir = nil
      @redis_url = ENV['REDIS_URL'] || 'redis://localhost:6379/0'
      @workflow_timeout = 300
      @max_retries = 3
      @retry_delay = 1
      @request_timeout = 30

      # New configuration options
      @enable_instrumentation = false
      @deprecation_warnings = true

      # A2A Protocol Configuration
      initialize_a2a_defaults
    end

    # Backward compatibility
    def api_key
      @openai_api_key
    end

    def api_key=(value)
      @openai_api_key = value
    end

    # Validation methods
    def valid_provider?
      %i[openai open_router anthropic].include?(@llm_provider)
    end

    def provider_configured?
      case @llm_provider
      when :openai
        @openai_api_key.present?
      when :open_router
        @open_router_api_key.present?
      when :anthropic
        @anthropic_api_key.present?
      else
        false
      end
    end

    def validate!
      unless valid_provider?
        raise ConfigurationError,
              "Invalid LLM provider: #{@llm_provider}. Must be one of: :openai, :open_router, :anthropic"
      end

      return if provider_configured?

      raise ConfigurationError, "API key not configured for provider: #{@llm_provider}"
    end

    # A2A Protocol Configuration Methods
    def initialize_a2a_defaults
      @a2a_server_enabled = false
      @a2a_server_port = 8080
      @a2a_server_host = '0.0.0.0'
      @a2a_auth_token = nil
      @a2a_base_url = nil
      @a2a_ssl_cert_path = nil
      @a2a_ssl_key_path = nil
      @a2a_default_timeout = 30
      @a2a_max_retries = 3
      @a2a_cache_ttl = 300
      @a2a_user_agent = "SuperAgent-A2A/#{defined?(SuperAgent::VERSION) ? SuperAgent::VERSION : '0.1.0'}"
      @a2a_agent_registry = {}
      @a2a_auto_discovery_enabled = false
    end

    def a2a_server_ssl_enabled?
      a2a_ssl_cert_path.present? && a2a_ssl_key_path.present?
    end

    def register_a2a_agent(name, url, options = {})
      @a2a_agent_registry[name] = {
        url: url,
        **options,
      }
    end

    def a2a_agent(name)
      @a2a_agent_registry[name]
    end

    private

    def default_logger
      require 'semantic_logger'
      SemanticLogger.default_level = :info
      SemanticLogger[SuperAgent]
    rescue LoadError
      # Fallback to standard Ruby logger if semantic_logger not available
      require 'logger'
      logger = Logger.new(STDOUT)
      logger.level = Logger::INFO
      logger
    end
  end
end
