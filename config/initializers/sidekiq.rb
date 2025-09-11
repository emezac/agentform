# Sidekiq Configuration for AgentForm
# This initializer configures Sidekiq for background job processing

require 'sidekiq'
require 'sidekiq/web'

# Use shared Redis configuration with SSL support
redis_config = RedisConfig.sidekiq_config

# Configure Sidekiq client (for enqueueing jobs)
Sidekiq.configure_client do |config|
  config.redis = redis_config
  
  # Client-specific error handling
  config.error_handlers << proc do |exception, context|
    case exception
    when Redis::CannotConnectError, Redis::ConnectionError, Redis::TimeoutError
      Rails.logger.error "Sidekiq Client Redis Connection Error: #{exception.message}"
      Rails.logger.error "Failed to enqueue job: #{context[:job_class] || 'Unknown'}"
      Rails.logger.error "Redis URL: #{ENV['REDIS_URL']&.gsub(/:[^:@]*@/, ':***@')}"
    else
      Rails.logger.error "Sidekiq Client Error: #{exception.message}"
      Rails.logger.error "Context: #{context}"
    end
    
    # Send to error tracking service
    if defined?(Sentry)
      Sentry.capture_exception(exception, extra: context.merge({
        component: 'sidekiq_client',
        redis_url_masked: ENV['REDIS_URL']&.gsub(/:[^:@]*@/, ':***@')
      }))
    end
  end
end

# Configure Sidekiq server (for processing jobs)
Sidekiq.configure_server do |config|
  config.redis = redis_config
  
  # Server-specific settings
  config.concurrency = ENV.fetch('SIDEKIQ_CONCURRENCY', '10').to_i
  
  # Enhanced error handling for Redis connection failures
  config.error_handlers << proc do |exception, context|
    case exception
    when Redis::CannotConnectError, Redis::ConnectionError, Redis::TimeoutError
      # Redis connection specific errors
      Rails.logger.error "Sidekiq Redis Connection Error: #{exception.message}"
      Rails.logger.error "Redis URL: #{ENV['REDIS_URL']&.gsub(/:[^:@]*@/, ':***@')}" # Mask password
      Rails.logger.error "Context: #{context}"
      
      # Attempt to reconnect after a brief delay
      sleep(1)
      Rails.logger.info "Attempting to reconnect to Redis..."
    else
      # General error handling
      Rails.logger.error "Sidekiq Error: #{exception.message}"
      Rails.logger.error "Context: #{context}"
    end
    
    # Send to error tracking service
    if defined?(Sentry)
      Sentry.capture_exception(exception, extra: context.merge({
        redis_url_masked: ENV['REDIS_URL']&.gsub(/:[^:@]*@/, ':***@'),
        sidekiq_version: Sidekiq::VERSION
      }))
    end
  end
  
  # Lifecycle callbacks with Redis connection verification
  config.on(:startup) do
    Rails.logger.info "Sidekiq server started"
    
    # Verify Redis connection on startup
    begin
      Sidekiq.redis(&:ping)
      Rails.logger.info "Sidekiq Redis connection verified successfully"
    rescue Redis::CannotConnectError, Redis::ConnectionError => e
      Rails.logger.error "Sidekiq Redis connection failed on startup: #{e.message}"
      Rails.logger.error "Redis URL: #{ENV['REDIS_URL']&.gsub(/:[^:@]*@/, ':***@')}"
      
      # Don't fail startup, but log the issue
      if defined?(Sentry)
        Sentry.capture_exception(e, extra: { 
          event: 'sidekiq_startup_redis_failure',
          redis_url_masked: ENV['REDIS_URL']&.gsub(/:[^:@]*@/, ':***@')
        })
      end
    end
  end
  
  config.on(:shutdown) do
    Rails.logger.info "Sidekiq server shutting down"
  end
end

# Redis connection health monitoring
module SidekiqRedisMonitor
  def self.check_connection
    Sidekiq.redis(&:ping)
    true
  rescue Redis::CannotConnectError, Redis::ConnectionError, Redis::TimeoutError => e
    Rails.logger.warn "Sidekiq Redis health check failed: #{e.message}"
    false
  end
  
  def self.connection_info
    Sidekiq.redis do |conn|
      info = conn.info
      {
        connected_clients: info['connected_clients'],
        used_memory_human: info['used_memory_human'],
        redis_version: info['redis_version'],
        ssl_enabled: ENV['REDIS_URL']&.start_with?('rediss://') || false
      }
    end
  rescue Redis::CannotConnectError, Redis::ConnectionError => e
    Rails.logger.error "Failed to get Redis connection info: #{e.message}"
    { error: e.message }
  end
end

# Periodic Redis connection monitoring (only in production)
if Rails.env.production?
  Thread.new do
    loop do
      sleep(300) # Check every 5 minutes
      unless SidekiqRedisMonitor.check_connection
        Rails.logger.error "Sidekiq Redis connection lost - monitoring thread detected failure"
        
        if defined?(Sentry)
          Sentry.capture_message("Sidekiq Redis connection monitoring failure", level: :warning)
        end
      end
    end
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

# Custom middleware for job tracking with Redis error handling
class JobTrackingMiddleware
  def call(worker, job, queue)
    start_time = Time.current
    Rails.logger.info "Starting job: #{worker.class.name} in queue: #{queue}"
    
    yield
    
    duration = Time.current - start_time
    Rails.logger.info "Completed job: #{worker.class.name} in #{duration.round(2)}s"
  rescue Redis::CannotConnectError, Redis::ConnectionError, Redis::TimeoutError => e
    Rails.logger.error "Job failed due to Redis connection: #{worker.class.name} - #{e.message}"
    Rails.logger.error "Redis URL: #{ENV['REDIS_URL']&.gsub(/:[^:@]*@/, ':***@')}"
    
    # Log additional context for Redis failures
    Rails.logger.error "Job details: #{job.inspect}"
    
    if defined?(Sentry)
      Sentry.capture_exception(e, extra: {
        worker_class: worker.class.name,
        job_id: job['jid'],
        queue: queue,
        redis_url_masked: ENV['REDIS_URL']&.gsub(/:[^:@]*@/, ':***@'),
        failure_type: 'redis_connection'
      })
    end
    
    raise
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
  
  # Configure dead job retention with enhanced Redis error handling
  Sidekiq.configure_server do |config|
    config.death_handlers << ->(job, ex) do
      case ex
      when Redis::CannotConnectError, Redis::ConnectionError, Redis::TimeoutError
        Rails.logger.error "Job died due to Redis connection failure: #{job['class']} - #{ex.message}"
        Rails.logger.error "Redis URL: #{ENV['REDIS_URL']&.gsub(/:[^:@]*@/, ':***@')}"
        
        # Attempt to log connection status
        begin
          connection_status = SidekiqRedisMonitor.connection_info
          Rails.logger.error "Redis connection status: #{connection_status}"
        rescue => status_error
          Rails.logger.error "Could not retrieve Redis status: #{status_error.message}"
        end
      else
        Rails.logger.error "Job died: #{job['class']} - #{ex.message}"
      end
      
      if defined?(Sentry)
        Sentry.capture_exception(ex, extra: {
          job_class: job['class'],
          job_id: job['jid'],
          event: 'job_death',
          redis_url_masked: ENV['REDIS_URL']&.gsub(/:[^:@]*@/, ':***@')
        })
      end
    end
  end
  
  # Add connection retry configuration for production
  Sidekiq.configure_client do |config|
    # Override redis config with retry settings for production
    production_redis_config = redis_config.merge({
      reconnect_attempts: 3,
      reconnect_delay: 1,
      reconnect_delay_max: 5
    })
    config.redis = production_redis_config
  end
  
  Sidekiq.configure_server do |config|
    # Override redis config with retry settings for production
    production_redis_config = redis_config.merge({
      reconnect_attempts: 5,
      reconnect_delay: 1,
      reconnect_delay_max: 10
    })
    config.redis = production_redis_config
  end
end