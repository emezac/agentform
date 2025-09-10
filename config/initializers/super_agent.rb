# SuperAgent Configuration for AgentForm
# This initializer configures the SuperAgent framework for AI-powered workflows

SuperAgent.configure do |config|
  # LLM Provider Configuration
  config.llm_provider = :openai
  config.openai_api_key = ENV['OPENAI_API_KEY']
  config.default_llm_model = 'gpt-4o-mini'
  config.default_llm_timeout = 60
  config.default_llm_retries = 3
  
  # Alternative providers (if needed)
  config.anthropic_api_key = ENV['ANTHROPIC_API_KEY']
  config.open_router_api_key = ENV['OPENROUTER_API_KEY']
  
  # Workflow Configuration
  config.workflow_timeout = 300 # 5 minutes
  config.max_retries = 3
  config.retry_delay = 2
  
  # Redis Configuration for background jobs
  config.redis_url = ENV['REDIS_URL'] || 'redis://localhost:6379/0'
  
  # Logging
  config.log_level = :info
  config.enable_instrumentation = true
  
  # Security
  config.sensitive_log_filter = [
    :password, :token, :secret, :key, :api_key, 
    /password/i, /token/i, /secret/i, /api_key/i
  ]
end

Rails.logger.info "SuperAgent initialized with provider: #{SuperAgent.configuration.llm_provider}" if defined?(Rails.logger)