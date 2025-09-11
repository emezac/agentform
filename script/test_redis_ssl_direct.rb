#!/usr/bin/env ruby
# frozen_string_literal: true

# Direct Redis SSL Connection Test
# This script tests Redis SSL connection with different configurations

begin
  require_relative '../config/environment'
rescue => e
  puts "Warning: Rails loading issue: #{e.message}" if ENV['DEBUG']
  require_relative '../config/environment'
end

class RedisSSLDirectTest
  def initialize
    @redis_url = ENV['REDIS_URL']
  end

  def run_tests
    puts "🔐 Direct Redis SSL Connection Test"
    puts "=" * 40
    puts "Redis URL: #{mask_url(@redis_url)}"
    puts "Environment: #{Rails.env}"
    puts

    test_basic_connection
    test_with_ssl_verify_none
    test_with_redisconfig
    test_rails_cache
    test_sidekiq_connection

    puts "\n✅ SSL connection tests completed"
  end

  private

  def test_basic_connection
    puts "1. Testing basic connection (no SSL config)..."
    
    begin
      redis = Redis.new(url: @redis_url)
      redis.ping
      puts "   ✅ Basic connection successful"
    rescue => e
      puts "   ❌ Basic connection failed: #{e.message}"
    end
  end

  def test_with_ssl_verify_none
    puts "\n2. Testing with SSL verify_mode NONE..."
    
    begin
      config = {
        url: @redis_url,
        ssl_params: {
          verify_mode: OpenSSL::SSL::VERIFY_NONE
        }
      }
      
      redis = Redis.new(config)
      result = redis.ping
      puts "   ✅ SSL VERIFY_NONE connection successful: #{result}"
      
      # Test basic operations
      test_key = "ssl_test_#{Time.current.to_i}"
      redis.set(test_key, "test_value")
      value = redis.get(test_key)
      redis.del(test_key)
      
      if value == "test_value"
        puts "   ✅ Basic operations successful"
      else
        puts "   ❌ Basic operations failed"
      end
      
    rescue => e
      puts "   ❌ SSL VERIFY_NONE connection failed: #{e.message}"
    end
  end

  def test_with_redisconfig
    puts "\n3. Testing with RedisConfig..."
    
    begin
      config = RedisConfig.connection_config
      puts "   Config: #{config.inspect}"
      
      redis = Redis.new(config)
      result = redis.ping
      puts "   ✅ RedisConfig connection successful: #{result}"
      
      # Test basic operations
      test_key = "redisconfig_test_#{Time.current.to_i}"
      redis.set(test_key, "test_value")
      value = redis.get(test_key)
      redis.del(test_key)
      
      if value == "test_value"
        puts "   ✅ RedisConfig operations successful"
      else
        puts "   ❌ RedisConfig operations failed"
      end
      
    rescue => e
      puts "   ❌ RedisConfig connection failed: #{e.message}"
    end
  end

  def test_rails_cache
    puts "\n4. Testing Rails cache..."
    
    begin
      test_key = "cache_ssl_test_#{Time.current.to_i}"
      test_value = { message: "ssl_test", timestamp: Time.current }
      
      Rails.cache.write(test_key, test_value)
      retrieved_value = Rails.cache.read(test_key)
      Rails.cache.delete(test_key)
      
      if retrieved_value && retrieved_value[:message] == "ssl_test"
        puts "   ✅ Rails cache operations successful"
      else
        puts "   ❌ Rails cache operations failed"
      end
      
    rescue => e
      puts "   ❌ Rails cache failed: #{e.message}"
    end
  end

  def test_sidekiq_connection
    puts "\n5. Testing Sidekiq connection..."
    
    begin
      Sidekiq.redis do |conn|
        result = conn.ping
        puts "   ✅ Sidekiq Redis connection successful: #{result}"
        
        info = conn.info
        puts "   Redis version: #{info['redis_version']}"
        puts "   Connected clients: #{info['connected_clients']}"
      end
      
    rescue => e
      puts "   ❌ Sidekiq Redis connection failed: #{e.message}"
    end
  end

  def mask_url(url)
    return 'Not configured' unless url
    return url unless url.include?('@')
    
    url.gsub(/:[^:@]*@/, ':***@')
  end
end

# Run the test if this script is executed directly
if __FILE__ == $0
  tester = RedisSSLDirectTest.new
  tester.run_tests
end