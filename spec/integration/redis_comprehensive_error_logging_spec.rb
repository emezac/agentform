# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Redis Comprehensive Error Logging Integration', type: :integration do
  let(:redis_connection_error) { Redis::CannotConnectError.new('Connection refused - connect(2) for 127.0.0.1:6379') }
  let(:redis_timeout_error) { Redis::TimeoutError.new('Timeout waiting for response') }

  before do
    # Clear any existing error counts
    Rails.cache.clear rescue nil
    
    # Enable Redis error logging in test environment
    allow(Rails.application.config).to receive(:log_redis_errors_in_test).and_return(true)
  end

  describe 'AdminNotificationService Redis error handling' do
    let(:user) { create(:user) }

    it 'handles Redis connection failures gracefully during notification creation' do
      # Mock Redis connection failure
      allow(AdminNotification).to receive(:notify_user_registered).and_raise(redis_connection_error)
      
      expect(Rails.logger).to receive(:warn).with(/Redis unavailable during admin notification creation/)
      expect(Rails.logger).to receive(:error).with(/Redis ERROR.*Connection refused/)
      
      result = AdminNotificationService.notify('user_registered', user: user)
      
      expect(result).to be_nil
    end

    it 'handles Redis connection failures gracefully during broadcast' do
      notification = create(:admin_notification)
      service = AdminNotificationService.new('user_registered', user: user)
      
      # Mock Turbo broadcast failure
      allow(Turbo::StreamsChannel).to receive(:broadcast_prepend_to).and_raise(redis_connection_error)
      
      expect(Rails.logger).to receive(:warn).with(/Redis unavailable for admin notification broadcast/)
      expect(Rails.logger).to receive(:error).with(/Redis ERROR.*Connection refused/)
      
      # Should not raise error
      expect { service.send(:broadcast_notification, notification) }.not_to raise_error
    end
  end

  describe 'GoogleSheets::RateLimiter Redis error handling' do
    let(:rate_limiter) { GoogleSheets::RateLimiter.new('test_key') }

    before do
      # Mock Redis connection to raise errors
      redis_double = double('Redis')
      allow(Redis).to receive(:current).and_return(redis_double)
      allow(redis_double).to receive(:get).and_raise(redis_connection_error)
      allow(redis_double).to receive(:multi).and_raise(redis_connection_error)
    end

    it 'allows operations to continue when Redis is unavailable' do
      expect(Rails.logger).to receive(:error).with(/Redis ERROR.*Connection refused/).at_least(:once)
      expect(Rails.logger).to receive(:warn).with(/Rate limiting disabled due to Redis connectivity issues/)
      
      executed = false
      
      expect {
        rate_limiter.execute do
          executed = true
        end
      }.not_to raise_error
      
      expect(executed).to be true
    end
  end

  describe 'AI::CachingService Redis error handling' do
    let(:content_hash) { 'test_hash_123' }
    let(:analysis_result) { { 'sentiment' => 'positive' } }

    before do
      # Mock Rails.cache to raise Redis errors
      allow(Rails.cache).to receive(:read).and_raise(redis_connection_error)
      allow(Rails.cache).to receive(:write).and_raise(redis_connection_error)
    end

    it 'handles cache read failures gracefully' do
      expect(Rails.logger).to receive(:error).with(/Redis ERROR.*Connection refused/)
      
      result = Ai::CachingService.get_cached_content_analysis(content_hash)
      
      expect(result).to be_nil
    end

    it 'handles cache write failures gracefully' do
      expect(Rails.logger).to receive(:error).with(/Redis ERROR.*Connection refused/)
      
      result = Ai::CachingService.cache_content_analysis(content_hash, analysis_result)
      
      # Should return the data even if caching failed
      expect(result[:analysis_result]).to eq(analysis_result)
    end
  end

  describe 'Sidekiq Redis error handling' do
    it 'logs comprehensive error information for job failures' do
      # Create a test job that will fail due to Redis connection
      test_job_class = Class.new do
        include Sidekiq::Job
        
        def perform
          # This will fail if Redis is unavailable
          Sidekiq.redis(&:ping)
        end
      end
      
      # Mock Sidekiq.redis to raise connection error
      allow(Sidekiq).to receive(:redis).and_raise(redis_connection_error)
      
      expect(Rails.logger).to receive(:error).with(/Sidekiq Redis Connection Error/)
      expect(Rails.logger).to receive(:error).with(/Redis URL:/)
      
      # The error should be handled by Sidekiq's error handlers
      expect {
        test_job_class.new.perform
      }.to raise_error(Redis::CannotConnectError)
    end
  end

  describe 'HealthController Redis diagnostics' do
    let(:health_controller) { HealthController.new }

    it 'provides comprehensive Redis diagnostics on health check failure' do
      # Mock RedisErrorLogger methods
      allow(RedisErrorLogger).to receive(:test_and_log_connection).and_return(false)
      allow(RedisErrorLogger).to receive(:get_connection_diagnostics).and_return({
        connection_status: 'failed',
        connection_error: 'Connection refused',
        redis_url_masked: 'redis://***@localhost:6379/0',
        ssl_enabled: false,
        environment: 'test'
      })
      
      result = health_controller.send(:check_redis)
      
      expect(result[:status]).to eq('error')
      expect(result[:message]).to eq('Connection refused')
      expect(result[:diagnostics]).to include(:connection_status, :redis_url_masked, :ssl_enabled)
    end
  end

  describe 'Error metrics tracking' do
    it 'tracks Redis errors by category and date' do
      # Generate different types of Redis errors
      RedisErrorLogger.log_connection_error(redis_connection_error, { component: 'test' })
      RedisErrorLogger.log_command_error(Redis::CommandError.new('WRONGTYPE'), { component: 'test' })
      RedisErrorLogger.log_redis_warning('Test warning', { component: 'test' })
      
      today = Date.current
      
      # Check error counters
      total_errors = Rails.cache.read("redis_errors:#{today}:total")
      connection_errors = Rails.cache.read("redis_errors:#{today}:connection")
      command_errors = Rails.cache.read("redis_errors:#{today}:command")
      warnings = Rails.cache.read("redis_warnings:#{today}")
      
      expect(total_errors).to eq(2) # connection + command error
      expect(connection_errors).to eq(1)
      expect(command_errors).to eq(1)
      expect(warnings).to eq(1)
    end
  end

  describe 'Sentry integration' do
    let(:sentry_double) { double('Sentry') }

    before do
      stub_const('Sentry', sentry_double)
    end

    it 'sends Redis errors to Sentry with comprehensive context' do
      expect(sentry_double).to receive(:capture_exception).with(
        redis_connection_error,
        extra: hash_including(
          error_class: 'Redis::CannotConnectError',
          error_category: 'connection',
          redis_url_masked: anything,
          environment: 'test'
        )
      )
      
      RedisErrorLogger.log_redis_error(redis_connection_error, { component: 'test' })
    end

    it 'sends connection recovery events to Sentry' do
      expect(sentry_double).to receive(:capture_message).with(
        'Redis connection recovered',
        level: :info,
        extra: hash_including(event_type: 'connection_recovery')
      )
      
      RedisErrorLogger.log_connection_recovery({ component: 'test' })
    end
  end

  describe 'SSL configuration logging' do
    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('REDIS_URL').and_return('rediss://user:password@redis-host:6380/0')
    end

    it 'includes SSL information in error logs' do
      result = RedisErrorLogger.log_redis_error(redis_connection_error, { component: 'test' })
      
      expect(result[:ssl_enabled]).to be true
      expect(result[:redis_url_masked]).to eq('rediss://user:***@redis-host:6380/0')
    end

    it 'includes SSL information in diagnostics' do
      diagnostics = RedisErrorLogger.get_connection_diagnostics
      
      expect(diagnostics[:ssl_enabled]).to be true
      expect(diagnostics[:redis_url_masked]).to eq('rediss://user:***@redis-host:6380/0')
    end
  end

  describe 'Configuration-based behavior' do
    it 'respects verbose logging configuration' do
      allow(Rails.application.config).to receive(:verbose_redis_logging).and_return(true)
      
      expect(Rails.logger).to receive(:info)
      
      RedisErrorLogger.log_redis_info('Test info message', { component: 'test' })
    end

    it 'skips debug logging when verbose logging is disabled' do
      allow(Rails.application.config).to receive(:verbose_redis_logging).and_return(false)
      
      expect(Rails.logger).not_to receive(:debug)
      
      RedisErrorLogger.log_redis_error(redis_connection_error, {}, severity: :debug)
    end
  end
end