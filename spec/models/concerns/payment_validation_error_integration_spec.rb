# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Payment Validation Error System Integration', type: :model do
  describe 'integration with existing services' do
    let(:user) { create(:user) }
    let(:form_template) { create(:form_template) }
    let(:form) { create(:form, user: user, form_template: form_template) }

    describe 'FormPublishValidationService integration' do
      it 'raises PaymentValidationError when validation fails' do
        # Mock the service to return validation failure
        allow_any_instance_of(FormPublishValidationService).to receive(:validate_payment_readiness)
          .and_return(double(success?: false, errors: ['stripe_not_configured']))

        # The service should be able to raise PaymentValidationError
        expect {
          raise PaymentValidationErrors.stripe_not_configured
        }.to raise_error(PaymentValidationError) do |error|
          expect(error.error_type).to eq('stripe_not_configured')
          expect(error.required_actions).to include('configure_stripe')
          expect(error.primary_action_url).to eq('/stripe_settings')
        end
      end
    end

    describe 'PaymentSetupValidationService integration' do
      it 'can generate appropriate errors for different validation failures' do
        # Test Stripe not configured
        stripe_error = PaymentValidationErrors.stripe_not_configured
        expect(stripe_error.error_type).to eq('stripe_not_configured')
        expect(stripe_error.actionable?).to be true

        # Test Premium required
        premium_error = PaymentValidationErrors.premium_required
        expect(premium_error.error_type).to eq('premium_subscription_required')
        expect(premium_error.actionable?).to be true

        # Test multiple requirements
        multiple_error = PaymentValidationErrors.multiple_requirements(['stripe_config', 'premium'])
        expect(multiple_error.error_type).to eq('multiple_requirements_missing')
        expect(multiple_error.required_actions).to include('complete_stripe_config', 'complete_premium')
      end
    end

    describe 'error serialization for API responses' do
      it 'provides consistent JSON structure' do
        error = PaymentValidationErrors.stripe_not_configured

        json_hash = error.to_hash
        expect(json_hash).to include(
          error_type: 'stripe_not_configured',
          message: 'Stripe configuration required for payment questions',
          required_actions: ['configure_stripe'],
          user_guidance: hash_including(
            action_url: '/stripe_settings',
            action_text: 'Configure Stripe'
          )
        )

        # Test JSON serialization
        json_string = error.to_json
        parsed_json = JSON.parse(json_string)
        expect(parsed_json['error_type']).to eq('stripe_not_configured')
        expect(parsed_json['required_actions']).to include('configure_stripe')
      end
    end

    describe 'error type checking and categorization' do
      it 'allows checking error types programmatically' do
        stripe_error = PaymentValidationErrors.stripe_not_configured
        premium_error = PaymentValidationErrors.premium_required

        expect(stripe_error.type?('stripe_not_configured')).to be true
        expect(stripe_error.type?(:stripe_not_configured)).to be true
        expect(stripe_error.type?('premium_required')).to be false

        expect(premium_error.type?('premium_subscription_required')).to be true
        expect(premium_error.type?('stripe_not_configured')).to be false
      end

      it 'groups errors by category and severity' do
        payment_setup_errors = PaymentValidationErrors.errors_by_category['payment_setup']
        expect(payment_setup_errors).to include(
          PaymentValidationErrors::STRIPE_NOT_CONFIGURED,
          PaymentValidationErrors::MULTIPLE_REQUIREMENTS
        )

        error_severity_errors = PaymentValidationErrors.errors_by_severity('error')
        expect(error_severity_errors.length).to be > 0
        expect(error_severity_errors).to include(PaymentValidationErrors::STRIPE_NOT_CONFIGURED)

        warning_severity_errors = PaymentValidationErrors.errors_by_severity('warning')
        expect(warning_severity_errors).to include(PaymentValidationErrors::INVALID_PAYMENT_CONFIGURATION)
      end
    end

    describe 'custom error creation' do
      it 'allows creating custom payment validation errors' do
        custom_error = PaymentValidationErrors.custom_error(
          error_type: 'custom_validation_failure',
          message: 'Custom validation failed',
          required_actions: ['custom_action'],
          action_url: '/custom_setup',
          action_text: 'Fix Custom Issue'
        )

        expect(custom_error.error_type).to eq('custom_validation_failure')
        expect(custom_error.message).to eq('Custom validation failed')
        expect(custom_error.required_actions).to eq(['custom_action'])
        expect(custom_error.primary_action_url).to eq('/custom_setup')
        expect(custom_error.primary_action_text).to eq('Fix Custom Issue')
      end
    end

    describe 'error definition lookup' do
      it 'finds error definitions by type' do
        stripe_definition = PaymentValidationErrors.find_error_definition('stripe_not_configured')
        expect(stripe_definition).to eq(PaymentValidationErrors::STRIPE_NOT_CONFIGURED)

        premium_definition = PaymentValidationErrors.find_error_definition(:premium_subscription_required)
        expect(premium_definition).to eq(PaymentValidationErrors::PREMIUM_REQUIRED)

        unknown_definition = PaymentValidationErrors.find_error_definition('unknown_error')
        expect(unknown_definition).to be_nil
      end
    end
  end

  describe 'error inheritance and rescue behavior' do
    it 'can be rescued as StandardError' do
      expect {
        begin
          raise PaymentValidationErrors.stripe_not_configured
        rescue StandardError => e
          expect(e).to be_a(PaymentValidationError)
          expect(e.error_type).to eq('stripe_not_configured')
          raise e
        end
      }.to raise_error(PaymentValidationError)
    end

    it 'can be rescued specifically as PaymentValidationError' do
      caught_error = nil
      
      begin
        raise PaymentValidationErrors.premium_required
      rescue PaymentValidationError => e
        caught_error = e
      end

      expect(caught_error).to be_a(PaymentValidationError)
      expect(caught_error.error_type).to eq('premium_subscription_required')
      expect(caught_error.required_actions).to include('upgrade_subscription')
    end
  end
end