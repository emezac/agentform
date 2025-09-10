# frozen_string_literal: true

SuperAgent.configure do |config|
  # =====================
  # LLM PROVIDER CONFIGURATION
  # =====================
  
  # Choose your primary LLM provider
  # Options: :openai, :open_router, :anthropic
  config.llm_provider = :openai

  # --- OpenAI Configuration ---
  config.openai_api_key = ENV['OPENAI_API_KEY']
  config.openai_organization_id = ENV['OPENAI_ORGANIZATION_ID']
  
  # --- OpenRouter Configuration ---
  # Required if llm_provider is :open_router
  config.open_router_api_key = ENV['OPENROUTER_API_KEY']
  # Optional: for branding in OpenRouter logs
  config.open_router_site_name = 'YourApp'
  config.open_router_site_url = 'https://yourapp.com'
  
  # --- Anthropic Configuration ---
  config.anthropic_api_key = ENV['ANTHROPIC_API_KEY']

  # =====================
  # MODEL CONFIGURATION
  # =====================
  
  # Default model - use full model names for OpenRouter (e.g., "openai/gpt-4")
  config.default_llm_model = "gpt-4"
  
  # Request settings
  config.default_llm_timeout = 30
  config.default_llm_retries = 2
  
  # =====================
  # LOGGING AND MONITORING
  # =====================
  
  config.logger = Rails.logger
  config.log_level = :info
  
  # Enable detailed instrumentation (ActiveSupport::Notifications)
  config.enable_instrumentation = false
  
  # Show deprecation warnings
  config.deprecation_warnings = true
  
  # =====================
  # SECURITY
  # =====================
  
  # Sensitive data filtering for logs
  config.sensitive_log_filter = [
    :password, :token, :secret, :key, :api_key,
    /password/i, /token/i, /secret/i, /api_key/i
  ]
  
  # =====================
  # BACKGROUND PROCESSING
  # =====================
  
  # ActiveJob queue for workflow processing
  config.async_queue = :default
  
  # Redis configuration (for background jobs and caching)
  config.redis_url = ENV['REDIS_URL'] || 'redis://localhost:6379/0'
  
  # Workflow timeout (in seconds)
  config.workflow_timeout = 300
  
  # Retry configuration
  config.max_retries = 3
  config.retry_delay = 1
  
  # =====================
  # DIRECTORIES
  # =====================
  
  # Custom paths for workflows and agents (optional)
  # config.workflows_dir = Rails.root.join('app', 'workflows')
  # config.agents_dir = Rails.root.join('app', 'agents')
end

# =====================
# INSTRUMENTATION SETUP (Optional)
# =====================

if SuperAgent.configuration.enable_instrumentation
  # Subscribe to SuperAgent events
  ActiveSupport::Notifications.subscribe('task.super_agent') do |name, start, finish, id, payload|
    duration = (finish - start) * 1000
    Rails.logger.info "[SuperAgent] Task #{payload[:name]} completed in #{duration.round(2)}ms"
  end

  ActiveSupport::Notifications.subscribe('task_error.super_agent') do |name, start, finish, id, payload|
    Rails.logger.error "[SuperAgent] Task #{payload[:name]} failed: #{payload[:error]}"
  end
end

# =====================
# DEVELOPMENT HELPERS
# =====================

if Rails.env.development?
  # Validate configuration on startup
  begin
    SuperAgent.configuration.validate!
    Rails.logger.info "[SuperAgent] Configuration validated successfully"
  rescue SuperAgent::ConfigurationError => e
    Rails.logger.warn "[SuperAgent] Configuration warning: #{e.message}"
  end
  
  # Log available models in development
  Rails.application.config.after_initialize do
    if SuperAgent.configuration.provider_configured?
      begin
        interface = SuperAgent::LlmInterface.new
        models = interface.available_models.first(5)
        Rails.logger.info "[SuperAgent] Available models: #{models.join(', ')}"
      rescue => e
        Rails.logger.warn "[SuperAgent] Could not fetch models: #{e.message}"
      end
    end
  end
end
