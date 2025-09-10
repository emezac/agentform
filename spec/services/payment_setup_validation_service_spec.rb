# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PaymentSetupValidationService, type: :service do
  let(:user) { create(:user) }

  describe '#call' do
    context 'with valid inputs' do
      let(:required_features) { %w[stripe_payments premium_subscription] }
      let(:service) { described_class.new(user: user, required_features: required_features) }

      context 'when user has complete setup' do
        before do
          user.update!(
            subscription_tier: 'premium',
            stripe_enabled: true,
            stripe_publishable_key: 'pk_test_123',
            stripe_secret_key: 'sk_test_123'
          )
        end

        it 'validates successfully' do
          service.call

          expect(service.success?).to be true
          expect(service.result[:valid]).to be true
          expect(service.result[:missing_requirements]).to be_empty
          expect(service.result[:setup_actions]).to be_empty
        end

        it 'sets correct context' do
          service.call

          expect(service.get_context(:features_validated)).to eq(2)
          expect(service.get_context(:requirements_missing)).to eq(0)
        end
      end

      context 'when user lacks Stripe configuration' do
        before do
          user.update!(subscription_tier: 'premium')
        end

        it 'identifies missing Stripe configuration' do
          service.call

          expect(service.success?).to be true
          expect(service.result[:valid]).to be false
          
          stripe_requirement = service.result[:missing_requirements].find { |r| r[:type] == 'stripe_configuration' }
          expect(stripe_requirement).to be_present
          expect(stripe_requirement[:title]).to eq('Stripe Configuration Required')
          expect(stripe_requirement[:priority]).to eq('high')
        end

        it 'generates Stripe setup action' do
          service.call

          stripe_action = service.result[:setup_actions].find { |a| a[:type] == 'stripe_setup' }
          expect(stripe_action).to be_present
          expect(stripe_action[:action_url]).to eq('/stripe_settings')
          expect(stripe_action[:priority]).to eq('high')
        end
      end

      context 'when user lacks Premium subscription' do
        before do
          user.update!(
            subscription_tier: 'freemium',
            stripe_enabled: true,
            stripe_publishable_key: 'pk_test_123',
            stripe_secret_key: 'sk_test_123'
          )
        end

        it 'identifies missing Premium subscription' do
          service.call

          expect(service.result[:valid]).to be false
          
          premium_requirement = service.result[:missing_requirements].find { |r| r[:type] == 'premium_subscription' }
          expect(premium_requirement).to be_present
          expect(premium_requirement[:title]).to eq('Premium Subscription Required')
          expect(premium_requirement[:current_tier]).to eq('freemium')
          expect(premium_requirement[:required_tier]).to eq('premium')
        end

        it 'generates subscription upgrade action' do
          service.call

          upgrade_action = service.result[:setup_actions].find { |a| a[:type] == 'subscription_upgrade' }
          expect(upgrade_action).to be_present
          expect(upgrade_action[:action_url]).to eq('/subscription_management')
        end
      end

      context 'when user lacks both Stripe and Premium' do
        before do
          user.update!(subscription_tier: 'freemium')
        end

        it 'identifies both missing requirements' do
          service.call

          expect(service.result[:valid]).to be false
          expect(service.result[:missing_requirements].length).to eq(2)
          expect(service.result[:setup_actions].length).to eq(2)
        end

        it 'sets correct context for multiple missing requirements' do
          service.call

          expect(service.get_context(:features_validated)).to eq(2)
          expect(service.get_context(:requirements_missing)).to eq(2)
        end
      end
    end

    context 'with subscription management requirements' do
      let(:required_features) { %w[stripe_payments premium_subscription subscription_management] }
      let(:service) { described_class.new(user: user, required_features: required_features) }

      context 'when user has basic setup but lacks subscription management' do
        before do
          user.update!(
            subscription_tier: 'premium',
            stripe_enabled: true,
            stripe_publishable_key: 'pk_test_123',
            stripe_secret_key: 'sk_test_123'
          )
        end

        it 'validates subscription management as complete when basic setup is done' do
          service.call

          expect(service.result[:valid]).to be true
          expect(service.result[:missing_requirements]).to be_empty
        end
      end

      context 'when user lacks premium for subscription management' do
        before do
          user.update!(subscription_tier: 'freemium')
        end

        it 'identifies subscription management as missing due to dependencies' do
          service.call

          subscription_requirement = service.result[:missing_requirements].find { |r| r[:type] == 'subscription_management' }
          expect(subscription_requirement).to be_present
          expect(subscription_requirement[:dependencies]).to include('premium_subscription', 'stripe_configuration')
        end
      end
    end

    context 'with webhook configuration requirements' do
      let(:required_features) { %w[stripe_payments webhook_configuration] }
      let(:service) { described_class.new(user: user, required_features: required_features) }

      context 'when user has Stripe but no webhook secret' do
        before do
          user.update!(
            subscription_tier: 'premium',
            stripe_enabled: true,
            stripe_publishable_key: 'pk_test_123',
            stripe_secret_key: 'sk_test_123'
          )
        end

        it 'identifies missing webhook configuration' do
          service.call

          webhook_requirement = service.result[:missing_requirements].find { |r| r[:type] == 'webhook_configuration' }
          expect(webhook_requirement).to be_present
          expect(webhook_requirement[:priority]).to eq('medium')
        end
      end

      context 'when user has webhook secret configured' do
        before do
          user.update!(
            subscription_tier: 'premium',
            stripe_enabled: true,
            stripe_publishable_key: 'pk_test_123',
            stripe_secret_key: 'sk_test_123',
            stripe_webhook_secret: 'whsec_test_123'
          )
        end

        it 'validates webhook configuration as complete' do
          service.call

          expect(service.result[:valid]).to be true
          webhook_requirement = service.result[:missing_requirements].find { |r| r[:type] == 'webhook_configuration' }
          expect(webhook_requirement).to be_nil
        end
      end
    end

    context 'with invalid inputs' do
      it 'fails when user is nil' do
        service = described_class.new(user: nil, required_features: [])
        service.call

        expect(service.failure?).to be true
        expect(service.errors[:user]).to include('is required')
      end

      it 'fails when user is not a User instance' do
        service = described_class.new(user: 'invalid', required_features: [])
        service.call

        expect(service.failure?).to be true
        expect(service.errors[:user]).to include('must be a User instance')
      end

      it 'fails when required_features is not an array' do
        service = described_class.new(user: user, required_features: 'invalid')
        service.call

        expect(service.failure?).to be true
        expect(service.errors[:required_features]).to include('must be an array')
      end
    end

    context 'with empty required features' do
      let(:service) { described_class.new(user: user, required_features: []) }

      it 'validates successfully with no requirements' do
        service.call

        expect(service.success?).to be true
        expect(service.result[:valid]).to be true
        expect(service.result[:missing_requirements]).to be_empty
        expect(service.result[:setup_actions]).to be_empty
      end
    end

    context 'with unknown required features' do
      let(:service) { described_class.new(user: user, required_features: ['unknown_feature']) }

      it 'handles unknown features gracefully' do
        service.call

        expect(service.success?).to be true
        expect(service.result[:valid]).to be true
        expect(service.result[:missing_requirements]).to be_empty
      end
    end
  end

  describe 'setup action generation' do
    let(:required_features) { %w[stripe_payments premium_subscription subscription_management webhook_configuration] }
    let(:service) { described_class.new(user: user, required_features: required_features) }

    before do
      user.update!(subscription_tier: 'freemium')
    end

    it 'generates all required setup actions' do
      service.call

      action_types = service.result[:setup_actions].map { |a| a[:type] }
      expect(action_types).to include(
        'stripe_setup',
        'subscription_upgrade',
        'subscription_management_setup',
        'webhook_setup'
      )
    end

    it 'includes estimated times for all actions' do
      service.call

      service.result[:setup_actions].each do |action|
        expect(action[:estimated_time]).to be_present
      end
    end

    it 'includes proper action URLs' do
      service.call

      stripe_action = service.result[:setup_actions].find { |a| a[:type] == 'stripe_setup' }
      expect(stripe_action[:action_url]).to eq('/stripe_settings')

      upgrade_action = service.result[:setup_actions].find { |a| a[:type] == 'subscription_upgrade' }
      expect(upgrade_action[:action_url]).to eq('/subscription_management')
    end

    it 'sets dependencies for subscription management action' do
      service.call

      subscription_action = service.result[:setup_actions].find { |a| a[:type] == 'subscription_management_setup' }
      expect(subscription_action[:dependencies]).to include('stripe_setup', 'subscription_upgrade')
    end
  end
end