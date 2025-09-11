# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Redis Cache SSL Configuration', type: :integration do
  describe 'RedisConfig.cache_config' do
    context 'in development environment' do
      around do |example|
        original_env = Rails.env
        Rails.env = 'development'
        
        example.run
        
        Rails.env = original_env
      end

      it 'provides basic Redis configuration without SSL' do
        config = RedisConfig.cache_config
        
        expect(config[:url]).to eq('redis://localhost:6379/0')
        expect(config[:namespace]).to eq('agentform_cache_development')
        expect(config[:compress]).to be true
        expect(config[:compression_threshold]).to eq(1024)
        expect(config[:expires_in]).to eq(3600.seconds)
        expect(config[:error_handler]).to be_a(Proc)
        expect(config).not_to have_key(:ssl_params)
      end
    end

    context 'in production environment with rediss:// URL' do
      around do |example|
        original_env = Rails.env
        original_url = ENV['REDIS_URL']
        
        Rails.env = 'production'
        ENV['REDIS_URL'] = 'rediss://user:pass@redis-host:6380/0'
        
        example.run
        
        Rails.env = original_env
        if original_url
          ENV['REDIS_URL'] = original_url
        else
          ENV.delete('REDIS_URL')
        end
      end

      it 'provides Redis configuration with SSL parameters' do
        config = RedisConfig.cache_config
        
        expect(config[:url]).to eq('rediss://user:pass@redis-host:6380/0')
        expect(config[:namespace]).to eq('agentform_cache_production')
        expect(config[:ssl_params]).to be_present
        expect(config[:ssl_params][:verify_mode]).to eq(OpenSSL::SSL::VERIFY_NONE)
        expect(config[:compress]).to be true
        expect(config[:error_handler]).to be_a(Proc)
      end
    end

    context 'in production environment with redis:// URL (no SSL)' do
      around do |example|
        original_env = Rails.env
        original_url = ENV['REDIS_URL']
        
        Rails.env = 'production'
        ENV['REDIS_URL'] = 'redis://user:pass@redis-host:6379/0'
        
        example.run
        
        Rails.env = original_env
        if original_url
          ENV['REDIS_URL'] = original_url
        else
          ENV.delete('REDIS_URL')
        end
      end

      it 'provides Redis configuration without SSL parameters' do
        config = RedisConfig.cache_config
        
        expect(config[:url]).to eq('redis://user:pass@redis-host:6379/0')
        expect(config[:namespace]).to eq('agentform_cache_production')
        expect(config).not_to have_key(:ssl_params)
      end
    end
  end

  describe 'error handling' do
    it 'includes proper error handler for cache operations' do
      config = RedisConfig.cache_config
      error_handler = config[:error_handler]
      
      expect(error_handler).to be_a(Proc)
      
      # Test error handler behavior
      allow(Rails.logger).to receive(:error)
      allow(RedisConfig).to receive(:handle_redis_error)
      
      result = error_handler.call(
        method: 'read',
        returning: 'default_value',
        exception: StandardError.new('test error')
      )
      
      expect(result).to eq('default_value')
      expect(RedisConfig).to have_received(:handle_redis_error)
    end
  end

  describe 'Rails cache store configuration' do
    context 'in non-test environment' do
      around do |example|
        original_env = Rails.env
        Rails.env = 'development'
        
        # Reload the Rails configuration
        Rails.application.config.cache_store = nil
        load Rails.root.join('config/initializers/redis.rb')
        
        example.run
        
        Rails.env = original_env
      end

      it 'configures Rails cache store to use Redis with SSL support' do
        expect(Rails.application.config.cache_store).to be_an(Array)
        expect(Rails.application.config.cache_store.first).to eq(:redis_cache_store)
        
        cache_config = Rails.application.config.cache_store.last
        expect(cache_config[:url]).to be_present
        expect(cache_config[:namespace]).to include('agentform_cache_')
        expect(cache_config[:error_handler]).to be_a(Proc)
      end
    end

    context 'in test environment' do
      it 'does not configure Redis cache store' do
        # In test environment, cache store should remain as default (null store for tests)
        expect(Rails.cache).to be_a(ActiveSupport::Cache::NullStore)
      end
    end
  end
end