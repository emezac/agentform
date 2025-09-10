# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StripeConfigurationChecker do
  let(:user) { create(:user) }

  describe '.configured?' do
    context 'when user has complete Stripe configuration' do
      before do
        user.update!(
          stripe_enabled: true,
          stripe_publishable_key: 'pk_test_123',
          stripe_secret_key: 'sk_test_123'
        )
      end

      it 'returns true' do
        expect(described_class.configured?(user)).to be true
      end
    end

    context 'when user lacks Stripe configuration' do
      it 'returns false for user without Stripe keys' do
        expect(described_class.configured?(user)).to be false
      end

      it 'returns false for user with only publishable key' do
        user.update!(stripe_publishable_key: 'pk_test_123')
        expect(described_class.configured?(user)).to be false
      end

      it 'returns false for user with only secret key' do
        user.update!(stripe_secret_key: 'sk_test_123')
        expect(described_class.configured?(user)).to be false
      end
    end

    context 'with invalid user' do
      it 'returns false for nil user' do
        expect(described_class.configured?(nil)).to be false
      end

      it 'returns false for non-User object' do
        expect(described_class.configured?('invalid')).to be false
      end
    end
  end

  describe '.configuration_status' do
    context 'with fully configured user' do
      before do
        user.update!(
          stripe_enabled: true,
          stripe_publishable_key: 'pk_test_123',
          stripe_secret_key: 'sk_test_123',
          stripe_webhook_secret: 'whsec_test_123'
        )

        # Mock successful Stripe connection
        allow(described_class).to receive(:test_stripe_connection).and_return({
          success: true,
          charges_enabled: true,
          details_submitted: true
        })
      end

      it 'returns complete configuration status' do
        status = described_class.configuration_status(user)

        expect(status[:configured]).to be true
        expect(status[:user_id]).to eq(user.id)
        expect(status[:missing_steps]).to be_empty
        expect(status[:overall_completion]).to eq(100)
        expect(status[:configuration_steps][:stripe_keys]).to eq('complete')
        expect(status[:configuration_steps][:account_status]).to eq('complete')
        expect(status[:configuration_steps][:webhook_setup]).to eq('complete')
        expect(status[:configuration_steps][:payment_methods]).to eq('complete')
      end
    end

    context 'with partially configured user' do
      before do
        user.update!(
          stripe_enabled: true,
          stripe_publishable_key: 'pk_test_123',
          stripe_secret_key: 'sk_test_123'
        )

        # Mock Stripe connection with incomplete account
        allow(described_class).to receive(:test_stripe_connection).and_return({
          success: true,
          charges_enabled: false,
          details_submitted: false
        })
      end

      it 'identifies missing configuration steps' do
        status = described_class.configuration_status(user)

        expect(status[:configured]).to be false
        expect(status[:missing_steps]).to include('account_verification', 'webhook_setup')
        expect(status[:overall_completion]).to eq(50) # 2 out of 4 steps complete
        expect(status[:configuration_steps][:stripe_keys]).to eq('complete')
        expect(status[:configuration_steps][:account_status]).to eq('incomplete')
        expect(status[:configuration_steps][:webhook_setup]).to eq('missing')
      end
    end

    context 'with unconfigured user' do
      it 'returns unconfigured status' do
        status = described_class.configuration_status(user)

        expect(status[:configured]).to be false
        expect(status[:overall_completion]).to eq(0)
        expect(status[:missing_steps]).to include(
          'stripe_keys', 
          'account_verification', 
          'webhook_setup', 
          'payment_methods'
        )
      end
    end

    context 'with invalid Stripe keys' do
      before do
        user.update_columns(
          stripe_enabled: true,
          stripe_publishable_key: 'invalid_key',
          stripe_secret_key: 'invalid_secret'
        )
      end

      it 'identifies invalid keys' do
        status = described_class.configuration_status(user)

        expect(status[:configuration_steps][:stripe_keys]).to eq('invalid')
        expect(status[:missing_steps]).to include('stripe_keys')
      end
    end

    context 'with invalid user' do
      it 'returns default unconfigured status for nil user' do
        status = described_class.configuration_status(nil)

        expect(status[:configured]).to be false
        expect(status[:user_id]).to be_nil
        expect(status[:missing_steps]).to eq(['All configuration missing'])
      end
    end
  end

  describe '.missing_configuration_steps' do
    context 'with partially configured user' do
      before do
        user.update!(
          stripe_publishable_key: 'pk_test_123'
          # Missing secret key and webhook
        )
      end

      it 'returns specific missing steps' do
        missing_steps = described_class.missing_configuration_steps(user)

        expect(missing_steps).to include('stripe_keys', 'account_verification', 'webhook_setup')
      end
    end

    context 'with unconfigured user' do
      it 'returns all configuration missing message' do
        missing_steps = described_class.missing_configuration_steps(nil)

        expect(missing_steps).to eq(['All Stripe configuration missing'])
      end
    end
  end

  describe '.validate_stripe_keys' do
    context 'with valid keys' do
      it 'validates correct test keys' do
        result = described_class.validate_stripe_keys('pk_test_123', 'sk_test_456')

        expect(result[:valid]).to be true
        expect(result[:errors]).to be_empty
        expect(result[:test_mode]).to be true
        expect(result[:live_mode]).to be false
      end

      it 'validates correct live keys' do
        result = described_class.validate_stripe_keys('pk_live_123', 'sk_live_456')

        expect(result[:valid]).to be true
        expect(result[:errors]).to be_empty
        expect(result[:test_mode]).to be false
        expect(result[:live_mode]).to be true
      end
    end

    context 'with invalid keys' do
      it 'identifies missing publishable key' do
        result = described_class.validate_stripe_keys('', 'sk_test_456')

        expect(result[:valid]).to be false
        expect(result[:errors]).to include('Publishable key is required')
      end

      it 'identifies missing secret key' do
        result = described_class.validate_stripe_keys('pk_test_123', '')

        expect(result[:valid]).to be false
        expect(result[:errors]).to include('Secret key is required')
      end

      it 'identifies invalid publishable key format' do
        result = described_class.validate_stripe_keys('invalid_key', 'sk_test_456')

        expect(result[:valid]).to be false
        expect(result[:errors]).to include('Publishable key must start with pk_')
      end

      it 'identifies invalid secret key format' do
        result = described_class.validate_stripe_keys('pk_test_123', 'invalid_key')

        expect(result[:valid]).to be false
        expect(result[:errors]).to include('Secret key must start with sk_')
      end

      it 'identifies multiple validation errors' do
        result = described_class.validate_stripe_keys('invalid_pk', 'invalid_sk')

        expect(result[:valid]).to be false
        expect(result[:errors].length).to eq(2)
      end
    end
  end

  describe '.test_stripe_connection' do
    context 'with configured user' do
      before do
        user.update!(
          stripe_enabled: true,
          stripe_publishable_key: 'pk_test_123',
          stripe_secret_key: 'sk_test_123'
        )
      end

      it 'returns success for valid connection' do
        # Mock successful Stripe client and account retrieval
        stripe_client = double('StripeClient')
        account = double('Account', 
          id: 'acct_123',
          type: 'standard',
          country: 'US',
          default_currency: 'usd',
          charges_enabled: true,
          payouts_enabled: true,
          details_submitted: true
        )
        
        allow(user).to receive(:stripe_client).and_return(stripe_client)
        allow(stripe_client).to receive_message_chain(:accounts, :retrieve).and_return(account)

        result = described_class.test_stripe_connection(user)

        expect(result[:success]).to be true
        expect(result[:account_id]).to eq('acct_123')
        expect(result[:charges_enabled]).to be true
        expect(result[:payouts_enabled]).to be true
      end

      it 'handles Stripe authentication errors' do
        allow(user).to receive(:stripe_client).and_raise(Stripe::AuthenticationError.new('Invalid API key'))

        result = described_class.test_stripe_connection(user)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Invalid Stripe API keys')
      end

      it 'handles general Stripe errors' do
        allow(user).to receive(:stripe_client).and_raise(Stripe::StripeError.new('API error'))

        result = described_class.test_stripe_connection(user)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Stripe API error')
      end

      it 'handles general connection errors' do
        allow(user).to receive(:stripe_client).and_raise(StandardError.new('Connection failed'))

        result = described_class.test_stripe_connection(user)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Connection test failed')
      end
    end

    context 'with unconfigured user' do
      it 'returns error for unconfigured user' do
        result = described_class.test_stripe_connection(user)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('User not configured for Stripe')
      end
    end
  end

  describe '.can_accept_live_payments?' do
    context 'with fully configured and verified user' do
      before do
        user.update!(
          stripe_enabled: true,
          stripe_publishable_key: 'pk_test_123',
          stripe_secret_key: 'sk_test_123'
        )

        allow(described_class).to receive(:configuration_status).and_return({
          configuration_steps: {
            stripe_keys: 'complete',
            account_status: 'complete'
          }
        })
      end

      it 'returns true' do
        expect(described_class.can_accept_live_payments?(user)).to be true
      end
    end

    context 'with incomplete configuration' do
      before do
        allow(described_class).to receive(:configured?).and_return(false)
      end

      it 'returns false' do
        expect(described_class.can_accept_live_payments?(user)).to be false
      end
    end
  end

  describe '.configuration_requirements' do
    before do
      allow(described_class).to receive(:configuration_status).and_return({
        missing_steps: ['stripe_keys', 'webhook_setup']
      })
    end

    it 'returns configuration requirements for missing steps' do
      requirements = described_class.configuration_requirements(user)

      expect(requirements.length).to eq(2)
      
      stripe_req = requirements.find { |r| r[:type] == 'stripe_keys' }
      expect(stripe_req[:title]).to eq('Stripe API Keys')
      expect(stripe_req[:priority]).to eq('high')

      webhook_req = requirements.find { |r| r[:type] == 'webhook_setup' }
      expect(webhook_req[:title]).to eq('Webhook Configuration')
      expect(webhook_req[:priority]).to eq('medium')
    end
  end
end