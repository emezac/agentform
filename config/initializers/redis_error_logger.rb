# frozen_string_literal: true

# Configuration for RedisErrorLogger
Rails.application.configure do
  # Enable Redis error logging in test environment only when explicitly requested
  config.log_redis_errors_in_test = ENV['LOG_REDIS_ERRORS_IN_TEST'] == 'true'
  
  # Enable verbose Redis logging in development or when explicitly requested
  config.verbose_redis_logging = Rails.env.development? || ENV['VERBOSE_REDIS_LOGGING'] == 'true'
end

# Set up periodic Redis connection monitoring in production
if Rails.env.production?
  # Monitor Redis connections every 5 minutes
  Thread.new do
    loop do
      sleep(300) # 5 minutes
      
      begin
        # Test connections for all major components
        components = ['sidekiq', 'cache', 'actioncable']
        
        components.each do |component|
          unless RedisErrorLogger.test_and_log_connection(component: component)
            RedisErrorLogger.log_redis_warning(
              "Periodic Redis connection check failed for #{component}",
              {
                component: component,
                check_type: 'periodic_monitoring',
                timestamp: Time.current.iso8601
              }
            )
          end
        end
      rescue => e
        RedisErrorLogger.log_redis_error(e, {
          component: 'periodic_monitor',
          operation: 'connection_check_loop'
        })
      end
    end
  end
end

# Add Redis error logging to Rails cache error handler
if Rails.cache.respond_to?(:options) && Rails.cache.options[:error_handler].nil?
  Rails.cache.options[:error_handler] = ->(method:, returning:, exception:) {
    RedisErrorLogger.log_redis_error(exception, {
      component: 'rails_cache',
      operation: method.to_s,
      cache_store: Rails.cache.class.name
    })
    
    returning
  }
end