# frozen_string_literal: true

module GoogleSheets
  class RateLimiter
    def initialize(key)
      @key = key
      @redis = Redis.current
    end
    
    def execute(&block)
      if within_limits?
        increment_counter
        yield
      else
        raise Google::Apis::RateLimitError.new("Rate limit exceeded for #{@key}")
      end
    rescue Redis::CannotConnectError, Redis::ConnectionError, Redis::TimeoutError => e
      # Log Redis error but allow operation to continue
      RedisErrorLogger.log_connection_error(e, {
        component: 'google_sheets_rate_limiter',
        operation: 'rate_limit_check',
        rate_limit_key: @key
      })
      
      # When Redis is unavailable, allow the operation to proceed
      # This ensures Google Sheets integration doesn't fail due to Redis issues
      Rails.logger.warn "Rate limiting disabled due to Redis connectivity issues for key: #{@key}"
      yield
    end
    
    private
    
    def within_limits?
      current_count < max_requests_per_minute
    rescue Redis::CannotConnectError, Redis::ConnectionError, Redis::TimeoutError => e
      RedisErrorLogger.log_connection_error(e, {
        component: 'google_sheets_rate_limiter',
        operation: 'within_limits_check',
        rate_limit_key: @key
      })
      
      # When Redis is unavailable, assume we're within limits to avoid blocking operations
      true
    end
    
    def current_count
      @redis.get("rate_limit:#{@key}:#{current_minute}").to_i
    rescue Redis::CannotConnectError, Redis::ConnectionError, Redis::TimeoutError => e
      RedisErrorLogger.log_connection_error(e, {
        component: 'google_sheets_rate_limiter',
        operation: 'current_count_check',
        rate_limit_key: @key
      })
      
      # Return 0 when Redis is unavailable
      0
    end
    
    def increment_counter
      key = "rate_limit:#{@key}:#{current_minute}"
      @redis.multi do |multi|
        multi.incr(key)
        multi.expire(key, 60)
      end
    rescue Redis::CannotConnectError, Redis::ConnectionError, Redis::TimeoutError => e
      RedisErrorLogger.log_connection_error(e, {
        component: 'google_sheets_rate_limiter',
        operation: 'increment_counter',
        rate_limit_key: @key,
        cache_key: key
      })
      
      # Don't raise error, just log it - rate limiting will be disabled
    end
    
    def current_minute
      Time.current.strftime('%Y%m%d%H%M')
    end
    
    def max_requests_per_minute
      # Use environment variable in production, fallback to credentials in development
      if Rails.env.production?
        ENV['GOOGLE_SHEETS_RATE_LIMIT_PER_MINUTE']&.to_i || 60
      else
        Rails.application.credentials.dig(:google_sheets_integration, :rate_limits, :requests_per_minute) || 60
      end
    end
  end
end