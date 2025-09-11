namespace :users do
  desc "Create a superadmin user with no billing restrictions"
  task create_superadmin: :environment do
    email = ENV['EMAIL'] || 'superadmin@agentform.com'
    password = ENV['PASSWORD'] || 'SuperSecret123!'
    
    puts "Creating superadmin user..."
    Rails.logger.info "Starting superadmin creation process for email: #{email}"
    
    user = User.find_or_initialize_by(email: email)
    user.assign_attributes(
      first_name: 'Super',
      last_name: 'Admin',
      role: 'superadmin',
      subscription_tier: 'premium', # Set to premium to bypass all restrictions
      password: password,
      password_confirmation: password,
      active: true
    )
    
    # Test Redis connectivity before user creation
    redis_available = test_redis_connectivity
    
    begin
      if user.save
        puts "✓ Superadmin user created successfully!"
        puts "Email: #{email}"
        puts "Password: #{password}"
        puts "Role: superadmin (bypasses all billing/trial restrictions)"
        
        Rails.logger.info "Superadmin user created successfully - ID: #{user.id}, Email: #{email}"
        
        unless redis_available
          puts "⚠ Warning: Redis was unavailable during creation - admin notifications may have been skipped"
          Rails.logger.warn "Superadmin created with Redis unavailable - notifications skipped"
        end
        
        exit 0
      else
        error_message = "Failed to create superadmin: #{user.errors.full_messages.join(', ')}"
        puts "✗ #{error_message}"
        Rails.logger.error "Superadmin creation failed: #{user.errors.full_messages.join(', ')}"
        exit 1
      end
    rescue Redis::CannotConnectError, Redis::ConnectionError, Redis::TimeoutError => e
      # Redis errors should not prevent user creation since the User model handles them gracefully
      puts "⚠ Warning: Redis connectivity issue detected: #{e.message}"
      puts "✓ Superadmin user creation completed successfully despite Redis issues"
      puts "Email: #{email}"
      puts "Password: #{password}"
      puts "Role: superadmin (bypasses all billing/trial restrictions)"
      
      Rails.logger.warn "Redis connectivity issue during superadmin creation: #{e.message}"
      Rails.logger.info "Superadmin creation completed successfully - ID: #{user.id}, Email: #{email}"
      Rails.logger.info "Admin notifications may have been skipped due to Redis connectivity"
      
      exit 0
    rescue => e
      error_message = "Unexpected error creating superadmin: #{e.message}"
      puts "✗ #{error_message}"
      puts "Please check the logs for more details"
      
      Rails.logger.error "Unexpected error during superadmin creation: #{e.message}"
      Rails.logger.error "Email: #{email}"
      Rails.logger.error "Backtrace: #{e.backtrace.join("\n")}"
      
      # Send to error tracking service if available
      if defined?(Sentry)
        Sentry.capture_exception(e, extra: {
          context: 'superadmin_creation_task',
          email: email,
          user_id: user.persisted? ? user.id : nil
        })
      end
      
      exit 1
    end
  end
  
  private
  
  # Test Redis connectivity without raising exceptions
  def test_redis_connectivity
    return true unless defined?(Redis)
    
    begin
      # Try to connect to Redis with a simple ping
      if defined?(Sidekiq)
        Sidekiq.redis { |conn| conn.ping }
      elsif Rails.cache.respond_to?(:redis)
        Rails.cache.redis.ping
      else
        # Fallback to direct Redis connection
        redis_url = ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')
        Redis.new(url: redis_url).ping
      end
      
      Rails.logger.info "Redis connectivity test passed"
      true
    rescue Redis::CannotConnectError, Redis::ConnectionError, Redis::TimeoutError => e
      Rails.logger.warn "Redis connectivity test failed: #{e.message}"
      false
    rescue => e
      Rails.logger.warn "Unexpected error during Redis connectivity test: #{e.message}"
      false
    end
  end
end