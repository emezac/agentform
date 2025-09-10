# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AdminSecurity do
  let(:dummy_class) do
    Class.new do
      include AdminSecurity
      
      attr_accessor :current_user, :request, :params, :controller_name, :action_name, :response
      
      def initialize
        @params = ActionController::Parameters.new
        @request = double('request', remote_ip: '127.0.0.1', user_agent: 'Test Agent', method: 'GET', path: '/test')
        @response = double('response', status: 200)
        @controller_name = 'test'
        @action_name = 'index'
      end
    end
  end
  
  let(:instance) { dummy_class.new }
  let(:user) { create(:user, role: 'superadmin') }
  
  before do
    instance.current_user = user
  end

  describe '#sanitize_string' do
    it 'removes script tags' do
      result = instance.send(:sanitize_string, '<script>alert("xss")</script>hello')
      expect(result).to eq('hello')
    end

    it 'removes SQL injection patterns' do
      result = instance.send(:sanitize_string, "'; DROP TABLE users; --")
      expect(result).to include('[FILTERED]')
    end

    it 'removes null bytes' do
      result = instance.send(:sanitize_string, "test\0malicious")
      expect(result).to eq('testmalicious')
    end

    it 'handles empty strings' do
      result = instance.send(:sanitize_string, '')
      expect(result).to eq('')
    end

    it 'handles nil values' do
      result = instance.send(:sanitize_string, nil)
      expect(result).to be_nil
    end

    it 'removes XSS patterns' do
      result = instance.send(:sanitize_string, 'javascript:alert("xss")')
      expect(result).to include('[FILTERED]')
    end

    it 'removes iframe tags' do
      result = instance.send(:sanitize_string, '<iframe src="evil.com"></iframe>')
      expect(result).to include('[FILTERED]')
    end
  end

  describe '#validate_email_format' do
    it 'accepts valid email' do
      expect {
        instance.send(:validate_email_format, 'test@example.com')
      }.not_to raise_error
    end

    it 'rejects invalid email' do
      expect {
        instance.send(:validate_email_format, 'invalid-email')
      }.to raise_error(ActionController::BadRequest, /Invalid email format/)
    end
  end

  describe '#validate_discount_code_format' do
    it 'accepts valid discount code' do
      expect {
        instance.send(:validate_discount_code_format, 'VALID123')
      }.not_to raise_error
    end

    it 'rejects invalid discount code with spaces' do
      expect {
        instance.send(:validate_discount_code_format, 'INVALID CODE')
      }.to raise_error(ActionController::BadRequest, /Invalid discount code format/)
    end

    it 'rejects too short discount code' do
      expect {
        instance.send(:validate_discount_code_format, 'AB')
      }.to raise_error(ActionController::BadRequest, /Invalid discount code format/)
    end

    it 'rejects too long discount code' do
      expect {
        instance.send(:validate_discount_code_format, 'A' * 21)
      }.to raise_error(ActionController::BadRequest, /Invalid discount code format/)
    end
  end

  describe '#validate_percentage' do
    it 'accepts valid percentage' do
      expect {
        instance.send(:validate_percentage, '50')
      }.not_to raise_error
    end

    it 'rejects percentage below 1' do
      expect {
        instance.send(:validate_percentage, '0')
      }.to raise_error(ActionController::BadRequest, /Discount percentage must be between 1 and 99/)
    end

    it 'rejects percentage above 99' do
      expect {
        instance.send(:validate_percentage, '100')
      }.to raise_error(ActionController::BadRequest, /Discount percentage must be between 1 and 99/)
    end
  end

  describe '#validate_role' do
    it 'accepts valid roles' do
      %w[user admin superadmin].each do |role|
        expect {
          instance.send(:validate_role, role)
        }.not_to raise_error
      end
    end

    it 'rejects invalid role' do
      expect {
        instance.send(:validate_role, 'invalid_role')
      }.to raise_error(ActionController::BadRequest, /Invalid role/)
    end
  end

  describe '#validate_subscription_tier' do
    it 'accepts valid tiers' do
      %w[basic premium freemium].each do |tier|
        expect {
          instance.send(:validate_subscription_tier, tier)
        }.not_to raise_error
      end
    end

    it 'rejects invalid tier' do
      expect {
        instance.send(:validate_subscription_tier, 'invalid_tier')
      }.to raise_error(ActionController::BadRequest, /Invalid subscription tier/)
    end
  end

  describe '#sanitize_hash' do
    it 'sanitizes string values in hash' do
      hash = { 'test' => '<script>alert("xss")</script>hello' }
      instance.send(:sanitize_hash, hash)
      expect(hash['test']).to eq('hello')
    end

    it 'sanitizes nested hashes' do
      hash = { 
        'nested' => { 
          'param' => '<script>alert("nested")</script>test' 
        } 
      }
      instance.send(:sanitize_hash, hash)
      expect(hash['nested']['param']).to eq('test')
    end

    it 'sanitizes arrays' do
      hash = { 
        'array' => ['<script>alert("array")</script>item1', 'clean_item'] 
      }
      instance.send(:sanitize_hash, hash)
      expect(hash['array'][0]).to eq('item1')
      expect(hash['array'][1]).to eq('clean_item')
    end
  end

  describe '#filtered_params' do
    it 'removes sensitive parameters' do
      instance.params = ActionController::Parameters.new({
        email: 'test@example.com',
        password: 'secret',
        stripe_secret_key: 'sk_test_123',
        authenticity_token: 'token123'
      })
      
      filtered = instance.send(:filtered_params)
      
      expect(filtered).to have_key('email')
      expect(filtered).not_to have_key('password')
      expect(filtered).not_to have_key('stripe_secret_key')
      expect(filtered).not_to have_key('authenticity_token')
    end
  end
end