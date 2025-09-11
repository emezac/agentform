# frozen_string_literal: true

namespace :redis do
  desc "Test Redis connections and generate diagnostics report"
  task diagnostics: :environment do
    puts "Redis Connection Diagnostics Report"
    puts "=" * 50
    puts "Generated at: #{Time.current.iso8601}"
    puts "Environment: #{Rails.env}"
    puts

    # Test basic Redis connection
    puts "1. Basic Redis Connection Test"
    puts "-" * 30
    
    basic_test = RedisErrorLogger.test_and_log_connection(component: 'basic')
    puts "Status: #{basic_test ? '✅ PASS' : '❌ FAIL'}"
    
    diagnostics = RedisErrorLogger.get_connection_diagnostics
    puts "Redis URL (masked): #{diagnostics[:redis_url_masked]}"
    puts "SSL Enabled: #{diagnostics[:ssl_enabled]}"
    puts "Connection Status: #{diagnostics[:connection_status]}"
    
    if diagnostics[:redis_version]
      puts "Redis Version: #{diagnostics[:redis_version]}"
      puts "Connected Clients: #{diagnostics[:connected_clients]}"
      puts "Memory Usage: #{diagnostics[:used_memory_human]}"
      puts "Uptime: #{diagnostics[:uptime_in_seconds]} seconds"
    end
    
    puts

    # Test component-specific connections
    components = ['sidekiq', 'cache', 'actioncable']
    
    puts "2. Component-Specific Connection Tests"
    puts "-" * 40
    
    components.each do |component|
      print "#{component.capitalize}: "
      
      test_result = RedisErrorLogger.test_and_log_connection(component: component)
      puts test_result ? '✅ PASS' : '❌ FAIL'
    end
    
    puts

    # Test Redis operations
    puts "3. Redis Operations Test"
    puts "-" * 25
    
    begin
      # Test basic operations
      test_key = "redis_diagnostics_test_#{Time.current.to_i}"
      test_value = "test_value_#{SecureRandom.hex(8)}"
      
      print "SET operation: "
      Rails.cache.write(test_key, test_value, expires_in: 1.minute)
      puts "✅ PASS"
      
      print "GET operation: "
      retrieved_value = Rails.cache.read(test_key)
      if retrieved_value == test_value
        puts "✅ PASS"
      else
        puts "❌ FAIL (value mismatch)"
      end
      
      print "DELETE operation: "
      Rails.cache.delete(test_key)
      puts "✅ PASS"
      
    rescue => e
      puts "❌ FAIL"
      RedisErrorLogger.log_redis_error(e, {
        component: 'diagnostics_task',
        operation: 'redis_operations_test'
      })
    end
    
    puts

    # Check Sidekiq Redis connection if available
    if defined?(Sidekiq)
      puts "4. Sidekiq Redis Connection"
      puts "-" * 30
      
      begin
        Sidekiq.redis do |conn|
          info = conn.info
          puts "Sidekiq Redis Version: #{info['redis_version']}"
          puts "Sidekiq Connected Clients: #{info['connected_clients']}"
          puts "Sidekiq Memory Usage: #{info['used_memory_human']}"
        end
        puts "Status: ✅ PASS"
      rescue => e
        puts "Status: ❌ FAIL"
        puts "Error: #{e.message}"
        RedisErrorLogger.log_connection_error(e, {
          component: 'diagnostics_task',
          operation: 'sidekiq_redis_test'
        })
      end
      
      puts
    end

    # Display recent Redis errors if any
    puts "5. Recent Redis Error Summary"
    puts "-" * 30
    
    begin
      # Try to get error counts from cache
      today = Date.current
      total_errors = Rails.cache.read("redis_errors:#{today}:total") || 0
      total_warnings = Rails.cache.read("redis_warnings:#{today}") || 0
      
      puts "Today's Redis Errors: #{total_errors}"
      puts "Today's Redis Warnings: #{total_warnings}"
      
      if total_errors > 0 || total_warnings > 0
        puts
        puts "Error breakdown by category:"
        %w[connection command protocol client].each do |category|
          count = Rails.cache.read("redis_errors:#{today}:#{category}") || 0
          puts "  #{category.capitalize}: #{count}" if count > 0
        end
      end
      
    rescue => e
      puts "Unable to retrieve error statistics (Redis may be unavailable)"
      RedisErrorLogger.log_redis_error(e, {
        component: 'diagnostics_task',
        operation: 'error_statistics'
      })
    end
    
    puts
    puts "Diagnostics complete. Check logs for detailed error information."
  end

  desc "Clear Redis error statistics"
  task clear_error_stats: :environment do
    puts "Clearing Redis error statistics..."
    
    begin
      today = Date.current
      yesterday = Date.yesterday
      
      # Clear today's and yesterday's stats
      [today, yesterday].each do |date|
        Rails.cache.delete("redis_errors:#{date}:total")
        Rails.cache.delete("redis_warnings:#{date}")
        
        %w[connection command protocol client].each do |category|
          Rails.cache.delete("redis_errors:#{date}:#{category}")
        end
      end
      
      puts "✅ Error statistics cleared successfully"
    rescue => e
      puts "❌ Failed to clear error statistics: #{e.message}"
      RedisErrorLogger.log_redis_error(e, {
        component: 'diagnostics_task',
        operation: 'clear_error_stats'
      })
    end
  end

  desc "Test Redis SSL configuration"
  task test_ssl: :environment do
    puts "Redis SSL Configuration Test"
    puts "=" * 35
    puts "Generated at: #{Time.current.iso8601}"
    puts "Environment: #{Rails.env}"
    puts

    diagnostics = RedisErrorLogger.get_connection_diagnostics
    
    puts "Redis URL (masked): #{diagnostics[:redis_url_masked]}"
    puts "SSL Enabled: #{diagnostics[:ssl_enabled]}"
    puts "Environment: #{diagnostics[:environment]}"
    puts

    if diagnostics[:ssl_enabled]
      puts "SSL Configuration Details:"
      puts "-" * 25
      
      # Test SSL connection specifically
      begin
        redis_url = ENV['REDIS_URL']
        
        if redis_url&.start_with?('rediss://')
          puts "✅ Redis URL uses SSL protocol (rediss://)"
          
          # Test SSL connection with verification disabled
          ssl_config = {
            url: redis_url,
            ssl_params: {
              verify_mode: OpenSSL::SSL::VERIFY_NONE
            }
          }
          
          test_redis = Redis.new(ssl_config)
          test_redis.ping
          
          puts "✅ SSL connection successful with VERIFY_NONE"
          
          # Get SSL-specific info
          info = test_redis.info
          puts "Connected via SSL to Redis #{info['redis_version']}"
          
        else
          puts "❌ Redis URL does not use SSL protocol"
        end
        
      rescue => e
        puts "❌ SSL connection failed: #{e.message}"
        RedisErrorLogger.log_connection_error(e, {
          component: 'diagnostics_task',
          operation: 'ssl_test'
        })
      end
    else
      puts "ℹ️  SSL is not enabled (not using rediss:// protocol)"
    end
    
    puts
    puts "SSL test complete."
  end

  desc "Run comprehensive production deployment verification"
  task verify_production: :environment do
    puts "🚀 Production Redis SSL Deployment Verification"
    puts "=" * 55
    puts "Environment: #{Rails.env}"
    puts "Timestamp: #{Time.current}"
    puts

    # Load and run the verification script
    verification_script = Rails.root.join('script', 'verify_redis_ssl_production.rb')
    
    if File.exist?(verification_script)
      load verification_script
      
      verifier = RedisSSLVerifier.new
      verifier.run_verification
    else
      puts "❌ Verification script not found at: #{verification_script}"
      puts "Please ensure script/verify_redis_ssl_production.rb exists"
      exit 1
    end
  end

  desc "Test Redis SSL connection directly with different configurations"
  task test_ssl_direct: :environment do
    puts "🔐 Direct Redis SSL Connection Test"
    puts "=" * 40
    
    # Load and run the direct SSL test script
    ssl_test_script = Rails.root.join('script', 'test_redis_ssl_direct.rb')
    
    if File.exist?(ssl_test_script)
      load ssl_test_script
      
      tester = RedisSSLDirectTest.new
      tester.run_tests
    else
      puts "❌ SSL test script not found at: #{ssl_test_script}"
      puts "Please ensure script/test_redis_ssl_direct.rb exists"
      exit 1
    end
  end

  desc "Monitor Redis connection health in real-time"
  task monitor: :environment do
    puts "📊 Redis Connection Health Monitor"
    puts "Press Ctrl+C to stop monitoring"
    puts "=" * 40
    
    trap("INT") { puts "\n👋 Monitoring stopped"; exit }
    
    loop do
      timestamp = Time.current.strftime("%H:%M:%S")
      
      # Test basic connection
      begin
        redis = Redis.new(RedisConfig.connection_config)
        latency_start = Time.current
        redis.ping
        latency = ((Time.current - latency_start) * 1000).round(2)
        
        print "#{timestamp} ✅ Redis: OK (#{latency}ms) | "
      rescue => e
        print "#{timestamp} ❌ Redis: FAILED (#{e.class.name}) | "
      end
      
      # Test Sidekiq
      begin
        Sidekiq.redis(&:ping)
        print "Sidekiq: OK | "
      rescue => e
        print "Sidekiq: FAILED | "
      end
      
      # Test Cache
      begin
        Rails.cache.write("monitor_test", Time.current.to_i)
        print "Cache: OK"
      rescue => e
        print "Cache: FAILED"
      end
      
      puts
      sleep 5
    end
  end
end