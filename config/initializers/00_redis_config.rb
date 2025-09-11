# frozen_string_literal: true

# RedisConfig - Centralized Redis configuration helper
# Provides consistent Redis connection settings across all components
# Handles SSL configuration for production Heroku Redis connections
class RedisConfig
  class << self
    # Returns the base Redis connection configuration
    # Includes SSL parameters for production Heroku Redis connections
    def connection_config
      config = {
        url: redis_url,
        network_timeout: network_timeout,
        pool_timeout: pool_timeout
      }
      
      # Add SSL configuration for production Heroku Redis
      if ssl_required?
        config[:ssl_params] = ssl_params
      end
      
      config
    end
    
    # Returns Redis configuration specifically for Rails cache
    def cache_config
      connection_config.merge({
        namespace: cache_namespace,
        expires_in: cache_ttl,
        compress: true,
        compression_threshold: 1024, # Compress entries larger than 1KB
        error_handler: cache_error_handler
      })
    end
    
    # Returns Redis configuration for ActionCable
    def cable_config
      config = connection_config.dup
      config[:channel_prefix] = cable_channel_prefix
      config
    end
    
    # Returns Redis configuration for Sidekiq
    def sidekiq_config
      connection_config
    end
    
    private
    
    # Determines the Redis URL based on environment
    def redis_url
      ENV.fetch('REDIS_URL', default_redis_url)
    end
    
    # Default Redis URL for development/test environments
    def default_redis_url
      case Rails.env
      when 'test'
        'redis://localhost:6379/1'
      else
        'redis://localhost:6379/0'
      end
    end
    
    # Determines if SSL is required (production with rediss:// URL)
    def ssl_required?
      Rails.env.production? && redis_url.start_with?('rediss://')
    end
    
    # SSL parameters for Heroku Redis (disable certificate verification)
    def ssl_params
      {
        verify_mode: OpenSSL::SSL::VERIFY_NONE
      }
    end
    
    # Network timeout for Redis connections
    def network_timeout
      ENV.fetch('REDIS_NETWORK_TIMEOUT', '5').to_i
    end
    
    # Pool timeout for Redis connections
    def pool_timeout
      ENV.fetch('REDIS_POOL_TIMEOUT', '5').to_i
    end
    
    # Cache namespace based on environment
    def cache_namespace
      "agentform_cache_#{Rails.env}"
    end
    
    # Default cache TTL
    def cache_ttl
      ENV.fetch('REDIS_CACHE_TTL', '3600').to_i.seconds # Default: 1 hour
    end
    
    # ActionCable channel prefix
    def cable_channel_prefix
      "agentform_#{Rails.env}"
    end
    
    # Error handler for cache operations
    def cache_error_handler
      ->(method:, returning:, exception:) {
        handle_redis_error(exception, { context: 'cache', method: method })
        returning
      }
    end
    
    # Centralized Redis error handling using RedisErrorLogger
    def handle_redis_error(exception, context = {})
      RedisErrorLogger.log_redis_error(exception, context.merge({
        component: 'redis_config',
        operation: context[:method] || 'unknown'
      }))
    end
    
    # Mask sensitive information in Redis URL for logging
    def mask_redis_url(url)
      return url unless url.include?('@')
      
      # Replace password with asterisks
      url.gsub(/:[^:@]*@/, ':***@')
    end
  end
end