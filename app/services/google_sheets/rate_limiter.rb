# frozen_string_literal: true

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
  end
  
  private
  
  def within_limits?
    current_count < max_requests_per_minute
  end
  
  def current_count
    @redis.get("rate_limit:#{@key}:#{current_minute}").to_i
  end
  
  def increment_counter
    key = "rate_limit:#{@key}:#{current_minute}"
    @redis.multi do |multi|
      multi.incr(key)
      multi.expire(key, 60)
    end
  end
  
  def current_minute
    Time.current.strftime('%Y%m%d%H%M')
  end
  
  def max_requests_per_minute
    Rails.application.credentials.dig(:google_sheets_integration, :rate_limits, :requests_per_minute) || 60
  end
end