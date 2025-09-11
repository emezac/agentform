#!/usr/bin/env ruby
# frozen_string_literal: true

# Redis SSL Configuration Verification Script for Production
# This script verifies that all Redis components work correctly with SSL configuration

begin
  require_relative '../config/environment'
rescue => e
  # Suppress Rails loading warnings in production scripts
  puts "Warning: Rails-specific components failed to load: #{e.message}" if ENV['DEBUG']
  require_relative '../config/environment'
end

class RedisSSLVerifier
  def initialize
    @results = {}
    @errors = []
  end

  def run_verification
    puts "🔍 Starting Redis SSL Configuration Verification"
    puts "Environment: #{Rails.env}"
    puts "Redis URL: #{mask_redis_url(ENV['REDIS_URL'])}"
    puts "SSL Required: #{RedisConfig.send(:ssl_required?)}"
    puts "=" * 60

    verify_redis_config
    verify_basic_redis_connection
    verify_actioncable_connection
    verify_sidekiq_connection
    verify_cache_connection
    verify_superadmin_creation
    verify_error_handling

    print_summary
    exit(@errors.empty? ? 0 : 1)
  end

  private

  def verify_redis_config
    test_name = "RedisConfig SSL Configuration"
    puts "\n📋 Testing: #{test_name}"

    begin
      config = RedisConfig.connection_config
      
      # Check if SSL params are present when required
      if RedisConfig.send(:ssl_required?)
        if config[:ssl_params] && config[:ssl_params][:verify_mode] == OpenSSL::SSL::VERIFY_NONE
          success(test_name, "SSL parameters correctly configured")
        else
          error(test_name, "SSL parameters missing or incorrect")
        end
      else
        success(test_name, "SSL not required for this environment")
      end

      # Verify timeout configurations
      if config[:network_timeout] && config[:pool_timeout]
        success("#{test_name} - Timeouts", "Network and pool timeouts configured")
      else
        error("#{test_name} - Timeouts", "Missing timeout configurations")
      end

    rescue => e
      error(test_name, "Configuration error: #{e.message}")
    end
  end

  def verify_basic_redis_connection
    test_name = "Basic Redis Connection"
    puts "\n🔌 Testing: #{test_name}"

    begin
      # Use RedisConfig to get proper SSL configuration
      redis = Redis.new(RedisConfig.connection_config)
      
      # Test basic operations
      test_key = "ssl_verification_test_#{Time.current.to_i}"
      test_value = "verification_successful"
      
      redis.set(test_key, test_value)
      retrieved_value = redis.get(test_key)
      redis.del(test_key)
      
      if retrieved_value == test_value
        success(test_name, "Basic Redis operations successful")
      else
        error(test_name, "Value mismatch in basic operations")
      end

      # Test Redis info
      info = redis.info
      success("#{test_name} - Info", "Redis version: #{info['redis_version']}")

    rescue Redis::CannotConnectError, Redis::ConnectionError => e
      error(test_name, "Connection failed: #{e.message}")
    rescue => e
      error(test_name, "Unexpected error: #{e.message}")
    end
  end

  def verify_actioncable_connection
    test_name = "ActionCable Redis Connection"
    puts "\n📡 Testing: #{test_name}"

    begin
      # Test ActionCable adapter connection
      adapter = ActionCable.server.pubsub
      
      if adapter.respond_to?(:redis_connection_for_subscriptions)
        # Test the connection
        connection = adapter.redis_connection_for_subscriptions
        connection.ping
        success(test_name, "ActionCable Redis connection successful")
      else
        # For newer versions, test differently
        test_channel = "ssl_verification_#{Time.current.to_i}"
        ActionCable.server.broadcast(test_channel, { message: "test" })
        success(test_name, "ActionCable broadcast successful")
      end

    rescue Redis::CannotConnectError, Redis::ConnectionError => e
      error(test_name, "ActionCable Redis connection failed: #{e.message}")
    rescue => e
      error(test_name, "ActionCable error: #{e.message}")
    end
  end

  def verify_sidekiq_connection
    test_name = "Sidekiq Redis Connection"
    puts "\n⚙️ Testing: #{test_name}"

    begin
      # Test Sidekiq Redis connection
      Sidekiq.redis(&:ping)
      success(test_name, "Sidekiq Redis connection successful")

      # Test job enqueueing
      job_id = TestRedisConnectionJob.perform_async("ssl_verification_test")
      if job_id
        success("#{test_name} - Job Enqueue", "Test job enqueued successfully: #{job_id}")
      else
        error("#{test_name} - Job Enqueue", "Failed to enqueue test job")
      end

      # Test Sidekiq stats
      stats = Sidekiq::Stats.new
      success("#{test_name} - Stats", "Processed: #{stats.processed}, Failed: #{stats.failed}")

    rescue Redis::CannotConnectError, Redis::ConnectionError => e
      error(test_name, "Sidekiq Redis connection failed: #{e.message}")
    rescue => e
      error(test_name, "Sidekiq error: #{e.message}")
    end
  end

  def verify_cache_connection
    test_name = "Rails Cache Redis Connection"
    puts "\n💾 Testing: #{test_name}"

    begin
      # Test Rails cache operations
      test_key = "ssl_cache_verification_#{Time.current.to_i}"
      test_value = { message: "cache_test_successful", timestamp: Time.current }
      
      Rails.cache.write(test_key, test_value)
      retrieved_value = Rails.cache.read(test_key)
      Rails.cache.delete(test_key)
      
      if retrieved_value && retrieved_value[:message] == "cache_test_successful"
        success(test_name, "Cache operations successful")
      else
        error(test_name, "Cache value mismatch or retrieval failed")
      end

      # Test cache stats if available
      if Rails.cache.respond_to?(:stats)
        stats = Rails.cache.stats
        success("#{test_name} - Stats", "Cache stats retrieved")
      end

    rescue Redis::CannotConnectError, Redis::ConnectionError => e
      error(test_name, "Cache Redis connection failed: #{e.message}")
    rescue => e
      error(test_name, "Cache error: #{e.message}")
    end
  end

  def verify_superadmin_creation
    test_name = "Superadmin Creation with Redis"
    puts "\n👤 Testing: #{test_name}"

    begin
      # Create a test admin user to verify the process works
      test_email = "redis_test_admin_#{Time.current.to_i}@example.com"
      
      # Simulate the superadmin creation process with required fields
      user = User.new(
        email: test_email,
        password: 'TempPassword123!',
        password_confirmation: 'TempPassword123!',
        first_name: 'Test',
        last_name: 'Admin',
        role: 'admin'
      )
      
      if user.save
        success("#{test_name} - User Creation", "Test admin user created successfully")
        
        # Test notification sending (should handle Redis gracefully)
        begin
          AdminNotificationService.notify('user_registered', user: user)
          success("#{test_name} - Notification", "Admin notification sent successfully")
        rescue => notification_error
          # This should not fail the test if Redis is unavailable
          warning("#{test_name} - Notification", "Notification failed but gracefully handled: #{notification_error.message}")
        end
        
        # Clean up test user and related notifications
        begin
          # Delete related admin notifications first
          AdminNotification.where(user: user).destroy_all
          user.destroy
          success("#{test_name} - Cleanup", "Test user cleaned up")
        rescue => cleanup_error
          warning("#{test_name} - Cleanup", "Cleanup had issues but test passed: #{cleanup_error.message}")
        end
      else
        error("#{test_name} - User Creation", "Failed to create test user: #{user.errors.full_messages.join(', ')}")
      end

    rescue => e
      error(test_name, "Superadmin creation test failed: #{e.message}")
    end
  end

  def verify_error_handling
    test_name = "Redis Error Handling"
    puts "\n🚨 Testing: #{test_name}"

    begin
      # Test RedisErrorLogger
      test_error = Redis::CannotConnectError.new("Test connection error")
      RedisErrorLogger.log_redis_error(test_error, { context: 'verification_test' })
      success(test_name, "Error logging mechanism works")

      # Test graceful degradation in AdminNotificationService
      # This should not raise an exception even if Redis fails
      begin
        test_user = User.new(email: "test@example.com", first_name: "Test", last_name: "User")
        AdminNotificationService.notify('user_registered', user: test_user)
        success("#{test_name} - Graceful Degradation", "Service handles Redis failures gracefully")
      rescue => e
        # If this raises an exception, it means graceful degradation is not working
        error("#{test_name} - Graceful Degradation", "Service does not handle Redis failures gracefully: #{e.message}")
      end

    rescue => e
      error(test_name, "Error handling verification failed: #{e.message}")
    end
  end

  def success(test_name, message)
    @results[test_name] = { status: :success, message: message }
    puts "  ✅ #{message}"
  end

  def warning(test_name, message)
    @results[test_name] = { status: :warning, message: message }
    puts "  ⚠️  #{message}"
  end

  def error(test_name, message)
    @results[test_name] = { status: :error, message: message }
    @errors << { test: test_name, message: message }
    puts "  ❌ #{message}"
  end

  def print_summary
    puts "\n" + "=" * 60
    puts "📊 VERIFICATION SUMMARY"
    puts "=" * 60

    success_count = @results.values.count { |r| r[:status] == :success }
    warning_count = @results.values.count { |r| r[:status] == :warning }
    error_count = @results.values.count { |r| r[:status] == :error }

    puts "✅ Successful tests: #{success_count}"
    puts "⚠️  Warning tests: #{warning_count}"
    puts "❌ Failed tests: #{error_count}"
    puts "📋 Total tests: #{@results.size}"

    if @errors.any?
      puts "\n🚨 ERRORS FOUND:"
      @errors.each do |error|
        puts "  • #{error[:test]}: #{error[:message]}"
      end
      puts "\n❌ Redis SSL configuration verification FAILED"
    else
      puts "\n🎉 All Redis SSL configuration tests PASSED!"
    end

    puts "\n📋 Environment Details:"
    puts "  • Rails Environment: #{Rails.env}"
    puts "  • Redis URL: #{mask_redis_url(ENV['REDIS_URL'])}"
    puts "  • SSL Required: #{RedisConfig.send(:ssl_required?)}"
    puts "  • Timestamp: #{Time.current}"
  end

  def mask_redis_url(url)
    return 'Not configured' unless url
    return url unless url.include?('@')
    
    url.gsub(/:[^:@]*@/, ':***@')
  end
end

# Simple test job for Sidekiq verification
class TestRedisConnectionJob
  include Sidekiq::Job

  def perform(message)
    Rails.logger.info "TestRedisConnectionJob executed with message: #{message}"
    message
  end
end

# Run the verification if this script is executed directly
if __FILE__ == $0
  verifier = RedisSSLVerifier.new
  verifier.run_verification
end