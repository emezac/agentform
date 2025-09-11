# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RedisConfig, type: :unit do
  describe '.connection_config' do
    context 'in test environment' do
      it 'uses test database URL' do
        config = RedisConfig.connection_config

        expect(config[:url]).to eq('redis://localhost:6379/1')
        expect(config).not_to have_key(:ssl_params)
      end
    end

    context 'in development environment' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
      end

      it 'returns basic Redis configuration without SSL' do
        config = RedisConfig.connection_config

        expect(config).to be_a(Hash)
        expect(config[:url]).to eq('redis://localhost:6379/0')
        expect(config[:network_timeout]).to eq(5)
        expect(config[:pool_timeout]).to eq(5)
        expect(config).not_to have_key(:ssl_params)
      end

      it 'uses environment variables for timeouts when available' do
        allow(ENV).to receive(:fetch).with('REDIS_NETWORK_TIMEOUT', '5').and_return('10')
        allow(ENV).to receive(:fetch).with('REDIS_POOL_TIMEOUT', '5').and_return('15')
        allow(ENV).to receive(:fetch).with('REDIS_URL', 'redis://localhost:6379/0').and_call_original

        config = RedisConfig.connection_config

        expect(config[:network_timeout]).to eq(10)
        expect(config[:pool_timeout]).to eq(15)
      end
    end

    context 'in production environment with SSL Redis' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
        allow(ENV).to receive(:fetch).with('REDIS_URL', anything).and_return('rediss://user:pass@redis-host:6380/0')
        allow(ENV).to receive(:fetch).with('REDIS_NETWORK_TIMEOUT', '5').and_return('5')
        allow(ENV).to receive(:fetch).with('REDIS_POOL_TIMEOUT', '5').and_return('5')
      end

      it 'includes SSL parameters for rediss:// URLs' do
        config = RedisConfig.connection_config

        expect(config[:url]).to eq('rediss://user:pass@redis-host:6380/0')
        expect(config).to have_key(:ssl_params)
        expect(config[:ssl_params]).to eq({ verify_mode: OpenSSL::SSL::VERIFY_NONE })
      end
    end

    context 'in production environment with regular Redis' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
        allow(ENV).to receive(:fetch).with('REDIS_URL', anything).and_return('redis://user:pass@redis-host:6379/0')
        allow(ENV).to receive(:fetch).with('REDIS_NETWORK_TIMEOUT', '5').and_return('5')
        allow(ENV).to receive(:fetch).with('REDIS_POOL_TIMEOUT', '5').and_return('5')
      end

      it 'does not include SSL parameters for regular redis:// URLs' do
        config = RedisConfig.connection_config

        expect(config[:url]).to eq('redis://user:pass@redis-host:6379/0')
        expect(config).not_to have_key(:ssl_params)
      end
    end
  end

  describe '.cache_config' do
    it 'includes cache-specific configuration' do
      config = RedisConfig.cache_config

      expect(config).to include(
        namespace: "agentform_cache_#{Rails.env}",
        expires_in: 3600,
        compress: true,
        compression_threshold: 1024
      )
      expect(config).to have_key(:error_handler)
    end

    it 'uses environment variable for cache TTL when available' do
      allow(ENV).to receive(:fetch).with('REDIS_CACHE_TTL', '3600').and_return('7200')
      allow(ENV).to receive(:fetch).with('REDIS_URL', anything).and_call_original
      allow(ENV).to receive(:fetch).with('REDIS_NETWORK_TIMEOUT', '5').and_call_original
      allow(ENV).to receive(:fetch).with('REDIS_POOL_TIMEOUT', '5').and_call_original

      config = RedisConfig.cache_config

      expect(config[:expires_in]).to eq(7200)
    end

    it 'includes proper error handler' do
      config = RedisConfig.cache_config
      error_handler = config[:error_handler]

      expect(error_handler).to be_a(Proc)

      # Test error handler behavior
      allow(RedisErrorLogger).to receive(:log_redis_error)
      
      result = error_handler.call(
        method: :get,
        returning: 'default_value',
        exception: StandardError.new('Redis connection failed')
      )

      expect(result).to eq('default_value')
      expect(RedisErrorLogger).to have_received(:log_redis_error)
    end
  end

  describe '.cable_config' do
    it 'includes ActionCable-specific configuration' do
      config = RedisConfig.cable_config

      expect(config).to have_key(:channel_prefix)
      expect(config[:channel_prefix]).to eq("agentform_#{Rails.env}")
    end

    it 'inherits base connection configuration' do
      config = RedisConfig.cable_config

      expect(config).to have_key(:url)
      expect(config).to have_key(:network_timeout)
      expect(config).to have_key(:pool_timeout)
    end
  end

  describe '.sidekiq_config' do
    it 'returns base connection configuration' do
      base_config = RedisConfig.connection_config
      sidekiq_config = RedisConfig.sidekiq_config

      expect(sidekiq_config).to eq(base_config)
    end
  end

  describe 'private methods' do
    describe '.ssl_required?' do
      context 'in production with rediss:// URL' do
        before do
          allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
          allow(ENV).to receive(:fetch).with('REDIS_URL', anything).and_return('rediss://user:pass@redis-host:6380/0')
        end

        it 'returns true' do
          expect(RedisConfig.send(:ssl_required?)).to be true
        end
      end

      context 'in production with redis:// URL' do
        before do
          allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
          allow(ENV).to receive(:fetch).with('REDIS_URL', anything).and_return('redis://user:pass@redis-host:6379/0')
        end

        it 'returns false' do
          expect(RedisConfig.send(:ssl_required?)).to be false
        end
      end

      context 'in development environment' do
        it 'returns false' do
          expect(RedisConfig.send(:ssl_required?)).to be false
        end
      end
    end

    describe '.ssl_params' do
      it 'returns correct SSL parameters' do
        ssl_params = RedisConfig.send(:ssl_params)

        expect(ssl_params).to eq({ verify_mode: OpenSSL::SSL::VERIFY_NONE })
      end
    end

    describe '.mask_redis_url' do
      it 'masks password in Redis URL' do
        url = 'redis://user:secret123@redis-host:6379/0'
        masked_url = RedisConfig.send(:mask_redis_url, url)

        expect(masked_url).to eq('redis://user:***@redis-host:6379/0')
      end

      it 'returns URL unchanged if no password present' do
        url = 'redis://redis-host:6379/0'
        masked_url = RedisConfig.send(:mask_redis_url, url)

        expect(masked_url).to eq(url)
      end
    end
  end

  describe 'error handling' do
    it 'handles Redis errors through RedisErrorLogger' do
      allow(RedisErrorLogger).to receive(:log_redis_error)
      
      exception = Redis::CannotConnectError.new('Connection failed')
      context = { component: 'test', operation: 'connect' }

      RedisConfig.send(:handle_redis_error, exception, context)

      expect(RedisErrorLogger).to have_received(:log_redis_error).with(
        exception,
        hash_including(
          component: 'redis_config',
          operation: 'unknown'
        )
      )
    end
  end
end