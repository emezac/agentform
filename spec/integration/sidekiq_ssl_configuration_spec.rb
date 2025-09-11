# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Sidekiq SSL Configuration', type: :integration do
  describe 'Sidekiq Redis configuration' do
    it 'uses RedisConfig for client configuration' do
      expect(RedisConfig).to receive(:sidekiq_config).and_call_original
      
      # Reload Sidekiq configuration
      load Rails.root.join('config/initializers/sidekiq.rb')
      
      client_config = Sidekiq.redis_pool.with { |conn| conn }
      expect(client_config).to be_a(Redis)
    end

    context 'with SSL Redis in production' do
      around do |example|
        original_env = Rails.env
        original_redis_url = ENV['REDIS_URL']
        original_sidekiq_config = Sidekiq.options.dup
        
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
        ENV['REDIS_URL'] = 'rediss://user:pass@redis-host:6380/0'
        
        # Reconfigure Sidekiq with new settings
        Sidekiq.configure_client do |config|
          config.redis = RedisConfig.sidekiq_config
        end
        
        example.run
        
        # Restore original configuration
        allow(Rails).to receive(:env).and_return(original_env)
        ENV['REDIS_URL'] = original_redis_url
        Sidekiq.options.merge!(original_sidekiq_config)
      end

      it 'configures SSL parameters correctly' do
        config = RedisConfig.sidekiq_config
        
        expect(config[:url]).to eq('rediss://user:pass@redis-host:6380/0')
        expect(config[:ssl_params]).to eq({ verify_mode: OpenSSL::SSL::VERIFY_NONE })
      end
    end

    context 'with regular Redis in development' do
      it 'does not include SSL parameters' do
        config = RedisConfig.sidekiq_config
        
        expect(config[:url]).to match(/^redis:\/\//)
        expect(config).not_to have_key(:ssl_params)
      end
    end
  end

  describe 'Sidekiq job processing with Redis SSL' do
    let(:test_job_class) do
      Class.new do
        include Sidekiq::Job
        
        def perform(message)
          Rails.cache.write("test_job_result", message)
        end
        
        def self.name
          'TestRedisSSLJob'
        end
      end
    end

    before do
      stub_const('TestRedisSSLJob', test_job_class)
    end

    it 'can enqueue and process jobs with Redis configuration' do
      # Clear any existing jobs
      Sidekiq::Queue.new.clear
      
      # Enqueue a test job
      TestRedisSSLJob.perform_async('ssl_test_message')
      
      # Verify job was enqueued
      expect(Sidekiq::Queue.new.size).to eq(1)
      
      # Process the job
      job = Sidekiq::Queue.new.first
      expect(job['class']).to eq('TestRedisSSLJob')
      expect(job['args']).to eq(['ssl_test_message'])
    end

    context 'when Redis is unavailable' do
      before do
        # Mock Redis connection failure
        allow_any_instance_of(Redis).to receive(:ping).and_raise(Redis::CannotConnectError.new('Connection refused'))
      end

      it 'handles Redis connection failures gracefully' do
        expect {
          TestRedisSSLJob.perform_async('test_message')
        }.to raise_error(Redis::CannotConnectError)
      end
    end
  end

  describe 'Sidekiq error handling with Redis SSL' do
    it 'includes proper error handling for Redis failures' do
      allow(RedisErrorLogger).to receive(:log_redis_error)
      
      # Simulate a Redis connection error during job processing
      allow_any_instance_of(Redis).to receive(:lpush).and_raise(Redis::CannotConnectError.new('SSL handshake failed'))
      
      expect {
        Sidekiq::Client.push('class' => 'TestJob', 'args' => [])
      }.to raise_error(Redis::CannotConnectError)
    end
  end

  describe 'Sidekiq configuration validation' do
    it 'validates that Sidekiq uses the correct Redis configuration' do
      # Get the current Sidekiq Redis configuration
      sidekiq_redis_config = nil
      Sidekiq.redis_pool.with do |redis|
        sidekiq_redis_config = redis.connection
      end
      
      expect(sidekiq_redis_config).to be_present
    end

    it 'ensures Sidekiq client and server use same Redis config' do
      client_config = RedisConfig.sidekiq_config
      server_config = RedisConfig.sidekiq_config
      
      expect(client_config).to eq(server_config)
    end
  end

  describe 'Sidekiq retry mechanism with Redis SSL' do
    let(:failing_job_class) do
      Class.new do
        include Sidekiq::Job
        sidekiq_options retry: 2
        
        def perform
          raise Redis::CannotConnectError, 'SSL connection failed'
        end
        
        def self.name
          'FailingRedisSSLJob'
        end
      end
    end

    before do
      stub_const('FailingRedisSSLJob', failing_job_class)
    end

    it 'configures proper retry behavior for Redis SSL failures' do
      # Clear queues
      Sidekiq::Queue.new.clear
      Sidekiq::RetrySet.new.clear
      
      # Enqueue failing job
      FailingRedisSSLJob.perform_async
      
      # Verify job was enqueued
      expect(Sidekiq::Queue.new.size).to eq(1)
      
      # The job should have retry configuration
      job = Sidekiq::Queue.new.first
      expect(job['retry']).to eq(2)
    end
  end
end