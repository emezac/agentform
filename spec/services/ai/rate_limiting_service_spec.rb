# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ai::RateLimitingService, type: :service do
  let(:user_id) { SecureRandom.uuid }
  let(:ip_address) { '192.168.1.1' }
  let(:service) { described_class.new(user_id: user_id, action: 'ai_generation') }

  before do
    Rails.cache.clear
  end

  describe '#check_rate_limit' do
    context 'with valid action' do
      it 'allows request within limit' do
        result = service.check_rate_limit
        
        expect(result[:success]).to be true
        expect(result[:remaining_requests]).to eq(9)
        expect(result[:reset_time]).to be_a(Time)
      end

      it 'increments counter on subsequent requests' do
        service.check_rate_limit
        result = service.check_rate_limit
        
        expect(result[:success]).to be true
        expect(result[:remaining_requests]).to eq(8)
      end
    end

    context 'when rate limit is exceeded' do
      before do
        # Make 10 requests to hit the limit
        10.times { service.check_rate_limit }
      end

      it 'blocks further requests' do
        result = service.check_rate_limit
        
        expect(result[:success]).to be false
        expect(result[:errors]).to include(match(/Rate limit exceeded/))
        expect(result[:retry_after]).to eq(1.hour)
      end

      it 'logs rate limit exceeded event' do
        allow(AuditLog).to receive(:create!)
        
        service.check_rate_limit
        
        expect(AuditLog).to have_received(:create!).with(
          hash_including(
            event_type: 'rate_limit_exceeded',
            user_id: user_id,
            details: hash_including(
              action: 'ai_generation',
              limit: 10
            )
          )
        )
      end
    end

    context 'with different actions' do
      it 'handles file_upload action' do
        service.action = 'file_upload'
        result = service.check_rate_limit
        
        expect(result[:success]).to be true
        expect(result[:remaining_requests]).to eq(19) # file_upload has limit of 20
      end

      it 'handles api_request action' do
        service.action = 'api_request'
        result = service.check_rate_limit
        
        expect(result[:success]).to be true
        expect(result[:remaining_requests]).to eq(99) # api_request has limit of 100
      end
    end

    context 'with IP address instead of user_id' do
      let(:service) { described_class.new(ip_address: ip_address, action: 'ai_generation') }

      it 'uses IP address for rate limiting' do
        result = service.check_rate_limit
        
        expect(result[:success]).to be true
        expect(result[:remaining_requests]).to eq(9)
      end
    end

    context 'with custom identifier' do
      let(:service) { described_class.new(identifier: 'custom_id', action: 'ai_generation') }

      it 'uses custom identifier for rate limiting' do
        result = service.check_rate_limit
        
        expect(result[:success]).to be true
        expect(result[:remaining_requests]).to eq(9)
      end
    end

    context 'without any identifier' do
      let(:service) { described_class.new(action: 'ai_generation') }

      it 'raises error when no identifier provided' do
        expect { service.check_rate_limit }.to raise_error(ArgumentError, /must be provided/)
      end
    end

    context 'with invalid action' do
      before { service.action = 'invalid_action' }

      it 'returns error for invalid action' do
        result = service.check_rate_limit
        
        expect(result[:success]).to be false
        expect(result[:errors]).to include('Invalid action')
      end
    end

    context 'without action' do
      before { service.action = nil }

      it 'returns error when action not provided' do
        result = service.check_rate_limit
        
        expect(result[:success]).to be false
        expect(result[:errors]).to include('Action is required')
      end
    end
  end

  describe '#reset_rate_limit' do
    before do
      # Make some requests first
      3.times { service.check_rate_limit }
    end

    it 'resets the rate limit counter' do
      service.reset_rate_limit
      result = service.check_rate_limit
      
      expect(result[:success]).to be true
      expect(result[:remaining_requests]).to eq(9) # Back to full limit minus this request
    end

    it 'returns success message' do
      result = service.reset_rate_limit
      
      expect(result[:success]).to be true
      expect(result[:message]).to eq('Rate limit reset successfully')
    end
  end

  describe '#get_rate_limit_status' do
    before do
      # Make some requests
      3.times { service.check_rate_limit }
    end

    it 'returns current rate limit status' do
      result = service.get_rate_limit_status
      
      expect(result[:success]).to be true
      expect(result[:action]).to eq('ai_generation')
      expect(result[:current_count]).to eq(3)
      expect(result[:limit]).to eq(10)
      expect(result[:remaining]).to eq(7)
      expect(result[:window_seconds]).to eq(1.hour)
      expect(result[:reset_time]).to be_a(Time)
    end

    context 'with invalid action' do
      before { service.action = 'invalid' }

      it 'returns error for invalid action' do
        result = service.get_rate_limit_status
        
        expect(result[:success]).to be false
        expect(result[:errors]).to include('Invalid action')
      end
    end
  end

  describe 'cache key generation' do
    it 'generates correct cache key for user_id' do
      service = described_class.new(user_id: user_id, action: 'ai_generation')
      service.check_rate_limit
      
      cache_key = "rate_limit:ai_generation:user:#{user_id}"
      expect(Rails.cache.read(cache_key)).to eq(1)
    end

    it 'generates correct cache key for ip_address' do
      service = described_class.new(ip_address: ip_address, action: 'ai_generation')
      service.check_rate_limit
      
      cache_key = "rate_limit:ai_generation:ip:#{ip_address}"
      expect(Rails.cache.read(cache_key)).to eq(1)
    end

    it 'generates correct cache key for custom identifier' do
      service = described_class.new(identifier: 'custom', action: 'ai_generation')
      service.check_rate_limit
      
      cache_key = "rate_limit:ai_generation:id:custom"
      expect(Rails.cache.read(cache_key)).to eq(1)
    end
  end

  describe 'different rate limits' do
    it 'enforces correct limits for different actions' do
      # Test ai_generation (10 requests/hour)
      ai_service = described_class.new(user_id: user_id, action: 'ai_generation')
      10.times { expect(ai_service.check_rate_limit[:success]).to be true }
      expect(ai_service.check_rate_limit[:success]).to be false

      # Test file_upload (20 requests/hour)
      file_service = described_class.new(user_id: user_id, action: 'file_upload')
      20.times { expect(file_service.check_rate_limit[:success]).to be true }
      expect(file_service.check_rate_limit[:success]).to be false

      # Test api_request (100 requests/hour)
      api_service = described_class.new(user_id: user_id, action: 'api_request')
      result = api_service.check_rate_limit
      expect(result[:remaining_requests]).to eq(99)
    end
  end
end