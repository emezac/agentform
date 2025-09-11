# Design Document

## Overview

The Redis SSL configuration issue in Heroku production is caused by the default Redis client configuration not properly handling SSL certificate verification for Heroku Redis add-ons. Heroku Redis uses SSL connections with certificates that require specific SSL configuration to work properly.

The solution involves updating Redis configurations across all components (ActionCable, Sidekiq, Rails cache) to properly handle SSL connections in production while maintaining backward compatibility with development environments.

## Architecture

The fix will be implemented across three main Redis integration points:

1. **ActionCable Configuration** (`config/cable.yml`)
2. **Sidekiq Configuration** (`config/initializers/sidekiq.rb`)
3. **Rails Cache Configuration** (`config/initializers/redis.rb`)

Each configuration will be updated to include proper SSL settings when running in production with Heroku Redis.

## Components and Interfaces

### Redis SSL Configuration Helper

A shared configuration helper will be created to provide consistent Redis connection settings across all components:

```ruby
# config/initializers/redis_config.rb
class RedisConfig
  def self.connection_config
    config = {
      url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'),
      network_timeout: 5,
      pool_timeout: 5
    }
    
    # Add SSL configuration for production Heroku Redis
    if Rails.env.production? && ENV['REDIS_URL']&.start_with?('rediss://')
      config[:ssl_params] = {
        verify_mode: OpenSSL::SSL::VERIFY_NONE
      }
    end
    
    config
  end
end
```

### ActionCable Configuration Update

The `config/cable.yml` will be updated to use proper SSL configuration:

```yaml
production:
  adapter: redis
  url: <%= ENV.fetch("REDIS_URL") { "redis://localhost:6379/1" } %>
  channel_prefix: agentform_production
  ssl_params:
    verify_mode: <%= OpenSSL::SSL::VERIFY_NONE if ENV['REDIS_URL']&.start_with?('rediss://') %>
```

### Sidekiq Configuration Update

The Sidekiq initializer will be updated to use the shared Redis configuration:

```ruby
# Use shared Redis configuration
redis_config = RedisConfig.connection_config

Sidekiq.configure_client do |config|
  config.redis = redis_config
end

Sidekiq.configure_server do |config|
  config.redis = redis_config
  # ... rest of configuration
end
```

### Rails Cache Configuration Update

The Rails cache configuration will be updated to handle SSL properly:

```ruby
# Use Redis for caching with proper SSL configuration
unless Rails.env.test?
  cache_config = RedisConfig.connection_config.merge({
    namespace: "agentform_cache_#{Rails.env}",
    expires_in: 1.hour,
    compress: true,
    compression_threshold: 1024,
    error_handler: ->(method:, returning:, exception:) {
      Rails.logger.error "Redis cache error in #{method}: #{exception.message}"
      returning
    }
  })
  
  config.cache_store = :redis_cache_store, cache_config
end
```

## Data Models

No data model changes are required for this fix. This is purely a configuration update.

## Error Handling

### Graceful Degradation Strategy

1. **ActionCable Fallback**: If Redis is unavailable, ActionCable will log errors but not crash the application
2. **Cache Fallback**: Rails cache will fall back to memory store if Redis is unavailable
3. **Sidekiq Resilience**: Jobs will be retried with exponential backoff if Redis connection fails
4. **Notification Service Update**: The admin notification service will be updated to handle Redis failures gracefully

### Error Logging Enhancement

Enhanced error logging will be added to help diagnose Redis connectivity issues:

```ruby
# Enhanced error handler for Redis connections
def handle_redis_error(exception, context = {})
  Rails.logger.error "Redis Error: #{exception.message}"
  Rails.logger.error "Context: #{context}"
  Rails.logger.error "Redis URL: #{ENV['REDIS_URL']&.gsub(/:[^:@]*@/, ':***@')}" # Mask password
  
  if defined?(Sentry)
    Sentry.capture_exception(exception, extra: context)
  end
end
```

### Superadmin Creation Fix

The superadmin creation task will be updated to handle Redis failures gracefully:

```ruby
# In the superadmin creation task
begin
  user.notify_admin_of_registration
rescue Redis::CannotConnectError => e
  Rails.logger.warn "Redis unavailable during superadmin creation: #{e.message}"
  Rails.logger.info "Superadmin created successfully, but notification skipped due to Redis connectivity"
end
```

## Testing Strategy

### Unit Tests

1. **Redis Configuration Tests**: Verify that Redis configuration is properly set for different environments
2. **SSL Parameter Tests**: Ensure SSL parameters are correctly applied in production
3. **Fallback Tests**: Test graceful degradation when Redis is unavailable

### Integration Tests

1. **ActionCable Integration**: Test real-time features with Redis SSL configuration
2. **Sidekiq Integration**: Test background job processing with SSL Redis
3. **Cache Integration**: Test caching functionality with SSL Redis

### Production Verification

1. **Connection Test**: Verify Redis connection works in production after deployment
2. **Feature Test**: Test all Redis-dependent features (notifications, caching, background jobs)
3. **Superadmin Creation Test**: Verify superadmin creation works without Redis errors

## Implementation Approach

The implementation will follow these steps:

1. **Create Redis Configuration Helper**: Centralize Redis connection configuration
2. **Update ActionCable Configuration**: Modify `cable.yml` for SSL support
3. **Update Sidekiq Configuration**: Modify Sidekiq initializer to use SSL configuration
4. **Update Rails Cache Configuration**: Modify Redis cache initializer for SSL
5. **Add Error Handling**: Implement graceful degradation for Redis failures
6. **Update Notification Service**: Make admin notifications Redis-failure resilient
7. **Test and Deploy**: Verify all configurations work in production

This approach ensures that Redis connectivity issues are resolved while maintaining application stability and providing proper fallback mechanisms.