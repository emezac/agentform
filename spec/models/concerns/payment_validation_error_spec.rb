# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PaymentValidationError, type: :model do
  describe '#initialize' do
    it 'creates error with required parameters' do
      error = PaymentValidationError.new(
        error_type: 'test_error',
        required_actions: ['action1', 'action2'],
        user_guidance: { message: 'Test message', action_url: '/test' }
      )

      expect(error.error_type).to eq('test_error')
      expect(error.required_actions).to eq(['action1', 'action2'])
      expect(error.user_guidance).to eq({ message: 'Test message', action_url: '/test' })
      expect(error.message).to eq('Test message')
    end

    it 'uses default message when user_guidance message is not provided' do
      error = PaymentValidationError.new(error_type: 'test_error')

      expect(error.message).to eq('Payment validation failed: test_error')
    end

    it 'handles empty required_actions and user_guidance' do
      error = PaymentValidationError.new(error_type: 'test_error')

      expect(error.required_actions).to eq([])
      expect(error.user_guidance).to eq({})
    end
  end

  describe '#to_hash' do
    it 'returns hash representation of error' do
      error = PaymentValidationError.new(
        error_type: 'stripe_not_configured',
        required_actions: ['configure_stripe'],
        user_guidance: { 
          message: 'Stripe configuration required',
          action_url: '/stripe_settings',
          action_text: 'Configure Stripe'
        }
      )

      expected_hash = {
        error_type: 'stripe_not_configured',
        message: 'Stripe configuration required',
        required_actions: ['configure_stripe'],
        user_guidance: {
          message: 'Stripe configuration required',
          action_url: '/stripe_settings',
          action_text: 'Configure Stripe'
        }
      }

      expect(error.to_hash).to eq(expected_hash)
    end
  end

  describe '#to_json' do
    it 'returns JSON representation of error' do
      error = PaymentValidationError.new(
        error_type: 'premium_required',
        required_actions: ['upgrade_subscription'],
        user_guidance: { message: 'Premium required' }
      )

      json_result = JSON.parse(error.to_json)
      
      expect(json_result['error_type']).to eq('premium_required')
      expect(json_result['message']).to eq('Premium required')
      expect(json_result['required_actions']).to eq(['upgrade_subscription'])
    end
  end

  describe '#type?' do
    let(:error) { PaymentValidationError.new(error_type: 'stripe_not_configured') }

    it 'returns true for matching error type' do
      expect(error.type?('stripe_not_configured')).to be true
      expect(error.type?(:stripe_not_configured)).to be true
    end

    it 'returns false for non-matching error type' do
      expect(error.type?('premium_required')).to be false
      expect(error.type?(:premium_required)).to be false
    end
  end

  describe '#actionable?' do
    it 'returns true when required_actions is not empty' do
      error = PaymentValidationError.new(
        error_type: 'test_error',
        required_actions: ['action1']
      )

      expect(error.actionable?).to be true
    end

    it 'returns false when required_actions is empty' do
      error = PaymentValidationError.new(
        error_type: 'test_error',
        required_actions: []
      )

      expect(error.actionable?).to be false
    end
  end

  describe '#primary_action_url' do
    it 'returns action_url from user_guidance' do
      error = PaymentValidationError.new(
        error_type: 'test_error',
        user_guidance: { action_url: '/test_url' }
      )

      expect(error.primary_action_url).to eq('/test_url')
    end

    it 'returns nil when action_url is not present' do
      error = PaymentValidationError.new(error_type: 'test_error')

      expect(error.primary_action_url).to be_nil
    end
  end

  describe '#primary_action_text' do
    it 'returns action_text from user_guidance' do
      error = PaymentValidationError.new(
        error_type: 'test_error',
        user_guidance: { action_text: 'Test Action' }
      )

      expect(error.primary_action_text).to eq('Test Action')
    end

    it 'returns nil when action_text is not present' do
      error = PaymentValidationError.new(error_type: 'test_error')

      expect(error.primary_action_text).to be_nil
    end
  end

  describe 'inheritance' do
    it 'inherits from StandardError' do
      error = PaymentValidationError.new(error_type: 'test_error')
      
      expect(error).to be_a(StandardError)
    end

    it 'can be rescued as StandardError' do
      expect {
        begin
          raise PaymentValidationError.new(error_type: 'test_error')
        rescue StandardError => e
          expect(e).to be_a(PaymentValidationError)
          raise e
        end
      }.to raise_error(PaymentValidationError)
    end
  end
end