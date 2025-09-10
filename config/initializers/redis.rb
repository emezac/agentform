# frozen_string_literal: true

# Configure Rails cache store to use Redis
Rails.application.configure do
  # Use Redis for caching in all environments except test
  unless Rails.env.test?
    config.cache_store = :redis_cache_store, {
      url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'),
      
      # Cache-specific configuration
      namespace: "agentform_cache_#{Rails.env}",
      expires_in: 1.hour, # Default TTL
      compress: true,
      compression_threshold: 1024, # Compress entries larger than 1KB
      
      # Error handling
      error_handler: ->(method:, returning:, exception:) {
        Rails.logger.error "Redis cache error in #{method}: #{exception.message}"
        # Return the default value instead of raising
        returning
      }
    }
  end
end