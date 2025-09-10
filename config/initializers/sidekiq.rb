# Sidekiq Configuration for AgentForm
# This initializer configures Sidekiq for background job processing

require 'sidekiq'
require 'sidekiq/web'

# Redis configuration
redis_config = {
  url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'),
  network_timeout: 5,
  pool_timeout: 5
}

# Configure Sidekiq client (for enqueueing jobs)
Sidekiq.configure_client do |config|
  config.redis = redis_config
end

# Configure Sidekiq server (for processing jobs)
Sidekiq.configure_server do |config|
  config.redis = redis_config
  
  # Server-specific settings
  config.concurrency = ENV.fetch('SIDEKIQ_CONCURRENCY', '10').to_i
  
  # Error handling
  config.error_handlers << proc do |exception, context|
    Rails.logger.error "Sidekiq Error: #{exception.message}"
    Rails.logger.error "Context: #{context}"
    
    # Send to error tracking service
    if defined?(Sentry)
      Sentry.capture_exception(exception, extra: context)
    end
  end
  
  # Lifecycle callbacks
  config.on(:startup) do
    Rails.logger.info "Sidekiq server started"
  end
  
  config.on(:shutdown) do
    Rails.logger.info "Sidekiq server shutting down"
  end
end

# Queue priorities (higher number = higher priority)
# Critical jobs (payment processing, urgent notifications)
# AI processing jobs (LLM calls, analysis)
# Integration jobs (webhooks, third-party APIs)
# Analytics jobs (data processing, reporting)
# Default jobs (general background tasks)

# Configure Sidekiq Web UI
Sidekiq::Web.use(Rack::Auth::Basic) do |user, password|
  # In production, use environment variables for authentication
  if Rails.env.production?
    [user, password] == [ENV['SIDEKIQ_WEB_USER'], ENV['SIDEKIQ_WEB_PASSWORD']]
  else
    # In development, allow easy access
    [user, password] == ['admin', 'password']
  end
end

# Custom middleware for job tracking
class JobTrackingMiddleware
  def call(worker, job, queue)
    start_time = Time.current
    Rails.logger.info "Starting job: #{worker.class.name} in queue: #{queue}"
    
    yield
    
    duration = Time.current - start_time
    Rails.logger.info "Completed job: #{worker.class.name} in #{duration.round(2)}s"
  rescue => e
    Rails.logger.error "Job failed: #{worker.class.name} - #{e.message}"
    raise
  end
end

# Add middleware to server chain
Sidekiq.configure_server do |config|
  config.server_middleware do |chain|
    chain.add JobTrackingMiddleware
  end
end

# Development-specific configuration
if Rails.env.development?
  # Enable verbose logging in development
  Sidekiq.logger.level = Logger::DEBUG
end

# Production-specific configuration
if Rails.env.production?
  # Enable performance monitoring
  Sidekiq.logger.level = Logger::INFO
  
  # Configure dead job retention
  Sidekiq.configure_server do |config|
    config.death_handlers << ->(job, ex) do
      Rails.logger.error "Job died: #{job['class']} - #{ex.message}"
    end
  end
end