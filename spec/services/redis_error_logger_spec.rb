# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RedisErrorLogger, type: :service do
  let(:redis_error) { Redis::CannotConnectError.new('Connection refused') }
  let(:command_error) { Redis::CommandError.new('WRONGTYPE Operation against a key holding the wrong kind of value') }
  let(:timeout_error) { Redis::TimeoutError.new('Timeout') }
  
  before do
    # Clear any existing error counts
    Rails.cache.clear rescue nil
    
    # Mock environment variables
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('REDIS_URL').and_return('redis://localhost:6379/0')
  end

  describe '.log_redis_error' do
    it 'logs Redis connection errors with proper context' do
      expect(Rails.logger).to receive(:error).with(/Redis ERROR.*Connection refused/)
      
      result = described_class.log_redis_error(redis_error, { component: 'test' })
      
      expect(result[:error_class]).to eq('Redis::CannotConnectError')
      expect(result[:error_message]).to eq('Connection refused')
      expect(result[:error_category]).to eq('connection')
      expect(result[:context][:component]).to eq('test')
      expect(result[:redis_url_masked]).to eq('redis://localhost:6379/0')
      expect(result[:environment]).to eq('test')
    end

    it 'categorizes different types of Redis errors correctly' do
      connection_result = described_class.log_redis_error(redis_error, {})
      command_result = described_class.log_redis_error(command_error, {})
      
      expect(connection_result[:error_category]).to eq('connection')
      expect(command_result[:error_category]).to eq('command')
    end

    it 'masks sensitive information in Redis URLs' do
      allow(ENV).to receive(:[]).with('REDIS_URL').and_return('redis://user:password@localhost:6379/0')
      
      result = described_class.log_redis_error(redis_error, {})
      
      expect(result[:redis_url_masked]).to eq('redis://user:***@localhost:6379/0')
    end

    it 'includes SSL information when using rediss://' do
      allow(ENV).to receive(:[]).with('REDIS_URL').and_return('rediss://user:password@redis-host:6380/0')
      
      result = described_class.log_redis_error(redis_error, {})
      
      expect(result[:ssl_enabled]).to be true
      expect(result[:redis_url_masked]).to eq('rediss://user:***@redis-host:6380/0')
    end

    it 'sends errors to Sentry when available' do
      sentry_double = double('Sentry')
      stub_const('Sentry', sentry_double)
      
      expect(sentry_double).to receive(:capture_exception).with(
        redis_error,
        extra: hash_including(
          error_class: 'Redis::CannotConnectError',
          error_category: 'connection'
        )
      )
      
      described_class.log_redis_error(redis_error, {})
    end

    it 'tracks error metrics' do
      described_class.log_redis_error(redis_error, {})
      
      # Check that error counters are incremented
      today = Date.current
      total_errors = Rails.cache.read("redis_errors:#{today}:total")
      connection_errors = Rails.cache.read("redis_errors:#{today}:connection")
      
      expect(total_errors).to eq(1)
      expect(connection_errors).to eq(1)
    end
  end

  describe '.log_connection_error' do
    it 'logs connection errors with enhanced context' do
      expect(Rails.logger).to receive(:error).with(/Redis ERROR.*Connection refused/)
      
      result = described_class.log_connection_error(redis_error, { component: 'sidekiq' })
      
      expect(result[:error_category]).to eq('connection')
      expect(result[:context][:component]).to eq('sidekiq')
      expect(result[:ssl_enabled]).to be false
    end
  end

  describe '.log_command_error' do
    it 'logs command errors with appropriate severity' do
      expect(Rails.logger).to receive(:warn).with(/Redis WARN.*WRONGTYPE/)
      
      result = described_class.log_command_error(command_error, { operation: 'get' })
      
      expect(result[:error_category]).to eq('command')
      expect(result[:context][:operation]).to eq('get')
    end
  end

  describe '.log_redis_warning' do
    it 'logs warnings with proper context' do
      expect(Rails.logger).to receive(:warn).with(/Redis WARNING.*Test warning/)
      
      described_class.log_redis_warning('Test warning', { component: 'test' })
      
      # Check that warning counter is incremented
      today = Date.current
      warnings = Rails.cache.read("redis_warnings:#{today}")
      expect(warnings).to eq(1)
    end
  end

  describe '.log_redis_info' do
    it 'logs informational messages' do
      expect(Rails.logger).to receive(:info).with(/Redis INFO.*Test info/)
      
      described_class.log_redis_info('Test info', { component: 'test' })
    end
  end

  describe '.log_connection_recovery' do
    it 'logs connection recovery events' do
      expect(Rails.logger).to receive(:info).with(/Redis INFO.*Redis connection recovered successfully/)
      
      described_class.log_connection_recovery({ component: 'sidekiq' })
    end

    it 'sends recovery events to Sentry' do
      sentry_double = double('Sentry')
      stub_const('Sentry', sentry_double)
      
      expect(sentry_double).to receive(:capture_message).with(
        'Redis connection recovered',
        level: :info,
        extra: hash_including(event_type: 'connection_recovery')
      )
      
      described_class.log_connection_recovery({})
    end
  end

  describe '.test_and_log_connection' do
    context 'when Redis is available' do
      before do
        allow(Sidekiq).to receive(:redis).and_yield(double(ping: 'PONG'))
      end

      it 'returns true and logs success for sidekiq component' do
        expect(Rails.logger).to receive(:info).with(/Redis connection test successful for sidekiq/)
        
        result = described_class.test_and_log_connection(component: 'sidekiq')
        
        expect(result).to be true
      end
    end

    context 'when Redis is unavailable' do
      before do
        allow(Sidekiq).to receive(:redis).and_raise(redis_error)
      end

      it 'returns false and logs error for sidekiq component' do
        expect(Rails.logger).to receive(:error).with(/Redis ERROR.*Connection refused/)
        
        result = described_class.test_and_log_connection(component: 'sidekiq')
        
        expect(result).to be false
      end
    end
  end

  describe '.get_connection_diagnostics' do
    it 'returns basic diagnostics when Redis is unavailable' do
      diagnostics = described_class.get_connection_diagnostics
      
      expect(diagnostics).to include(
        :redis_url_masked,
        :ssl_enabled,
        :environment,
        :timestamp
      )
      expect(diagnostics[:environment]).to eq('test')
      expect(diagnostics[:ssl_enabled]).to be false
    end

    context 'when Redis is available' do
      let(:redis_info) do
        {
          'redis_version' => '6.2.0',
          'connected_clients' => '2',
          'used_memory_human' => '1.5M',
          'uptime_in_seconds' => '3600'
        }
      end

      before do
        redis_double = double('Redis')
        allow(redis_double).to receive(:info).and_return(redis_info)
        allow(Redis).to receive(:new).and_return(redis_double)
      end

      it 'includes Redis server information' do
        diagnostics = described_class.get_connection_diagnostics
        
        expect(diagnostics[:redis_version]).to eq('6.2.0')
        expect(diagnostics[:connected_clients]).to eq('2')
        expect(diagnostics[:used_memory_human]).to eq('1.5M')
        expect(diagnostics[:uptime_in_seconds]).to eq('3600')
        expect(diagnostics[:connection_status]).to eq('connected')
      end
    end
  end

  describe 'error categorization' do
    it 'categorizes connection errors correctly' do
      connection_errors = [
        Redis::CannotConnectError.new('test'),
        Redis::ConnectionError.new('test'),
        Redis::TimeoutError.new('test'),
        Redis::ReadOnlyError.new('test')
      ]

      connection_errors.each do |error|
        result = described_class.log_redis_error(error, {})
        expect(result[:error_category]).to eq('connection')
      end
    end

    it 'categorizes command errors correctly' do
      command_errors = [
        Redis::CommandError.new('test'),
        Redis::WrongTypeError.new('test')
      ]

      command_errors.each do |error|
        result = described_class.log_redis_error(error, {})
        expect(result[:error_category]).to eq('command')
      end
    end

    it 'categorizes unknown errors as unknown' do
      unknown_error = StandardError.new('test')
      
      result = described_class.log_redis_error(unknown_error, {})
      
      expect(result[:error_category]).to eq('unknown')
    end
  end

  describe 'configuration-based logging' do
    it 'respects test environment logging configuration' do
      allow(Rails.application.config).to receive(:log_redis_errors_in_test).and_return(false)
      
      expect(Rails.logger).not_to receive(:error)
      
      described_class.log_redis_error(redis_error, {}, severity: :error)
    end

    it 'logs in test environment when explicitly enabled' do
      allow(Rails.application.config).to receive(:log_redis_errors_in_test).and_return(true)
      
      expect(Rails.logger).to receive(:error)
      
      described_class.log_redis_error(redis_error, {}, severity: :error)
    end

    it 'respects verbose logging configuration' do
      allow(Rails.application.config).to receive(:verbose_redis_logging).and_return(true)
      
      expect(Rails.logger).to receive(:info)
      
      described_class.log_redis_error(redis_error, {}, severity: :info)
    end
  end
end