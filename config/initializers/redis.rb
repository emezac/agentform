# frozen_string_literal: true

# Configure Rails cache store to use Redis with SSL support
Rails.application.configure do
  # Use Redis for caching in all environments except test
  unless Rails.env.test?
    # Use centralized Redis configuration with SSL support
    config.cache_store = :redis_cache_store, RedisConfig.cache_config
  end
end