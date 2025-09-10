# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PaymentValidationErrors, type: :module do
  describe 'constants' do
    it 'defines STRIPE_NOT_CONFIGURED error type' do
      expect(PaymentValidationErrors::STRIPE_NOT_CONFIGURED).to include(
        type: 'stripe_not_configured',
        message: 'Stripe configuration required for payment questions',
        action_url: '/stripe_settings',
        action_text: 'Configure Stripe',
        severity: 'error',
        category: 'payment_setup'
      )
    end

    it 'defines PREMIUM_REQUIRED error type' do
      expect(PaymentValidationErrors::PREMIUM_REQUIRED).to include(
        type: 'premium_subscription_required',
        message: 'Premium subscription required for payment features',
        action_url: '/subscription_management',
        action_text: 'Upgrade to Premium',
        severity: 'error',
        category: 'subscription'
      )
    end

    it 'defines MULTIPLE_REQUIREMENTS error type' do
      expect(PaymentValidationErrors::MULTIPLE_REQUIREMENTS).to include(
        type: 'multiple_requirements_missing',
        message: 'Multiple setup steps required for payment features',
        action_url: '/payment_setup_guide',
        action_text: 'Complete Setup',
        severity: 'error',
        category: 'payment_setup'
      )
    end

    it 'defines INVALID_PAYMENT_CONFIGURATION error type' do
      expect(PaymentValidationErrors::INVALID_PAYMENT_CONFIGURATION).to include(
        type: 'invalid_payment_configuration',
        message: 'Payment questions are not properly configured',
        action_text: 'Review Questions',
        severity: 'warning',
        category: 'configuration'
      )
    end

    it 'defines INSUFFICIENT_PERMISSIONS error type' do
      expect(PaymentValidationErrors::INSUFFICIENT_PERMISSIONS).to include(
        type: 'insufficient_permissions',
        message: 'Insufficient permissions for payment features',
        action_url: '/profile',
        action_text: 'Contact Support',
        severity: 'error',
        category: 'permissions'
      )
    end

    it 'includes all error types in ALL_ERROR_TYPES' do
      expect(PaymentValidationErrors::ALL_ERROR_TYPES).to include(
        PaymentValidationErrors::STRIPE_NOT_CONFIGURED,
        PaymentValidationErrors::PREMIUM_REQUIRED,
        PaymentValidationErrors::MULTIPLE_REQUIREMENTS,
        PaymentValidationErrors::INVALID_PAYMENT_CONFIGURATION,
        PaymentValidationErrors::INSUFFICIENT_PERMISSIONS
      )
    end
  end

  describe '.stripe_not_configured' do
    it 'creates PaymentValidationError for Stripe not configured' do
      error = PaymentValidationErrors.stripe_not_configured

      expect(error).to be_a(PaymentValidationError)
      expect(error.error_type).to eq('stripe_not_configured')
      expect(error.required_actions).to eq(['configure_stripe'])
      expect(error.user_guidance).to eq(PaymentValidationErrors::STRIPE_NOT_CONFIGURED)
    end

    it 'includes additional actions when provided' do
      error = PaymentValidationErrors.stripe_not_configured(
        additional_actions: ['verify_webhook', 'test_connection']
      )

      expect(error.required_actions).to eq(['configure_stripe', 'verify_webhook', 'test_connection'])
    end
  end

  describe '.premium_required' do
    it 'creates PaymentValidationError for Premium subscription required' do
      error = PaymentValidationErrors.premium_required

      expect(error).to be_a(PaymentValidationError)
      expect(error.error_type).to eq('premium_subscription_required')
      expect(error.required_actions).to eq(['upgrade_subscription'])
      expect(error.user_guidance).to eq(PaymentValidationErrors::PREMIUM_REQUIRED)
    end

    it 'includes additional actions when provided' do
      error = PaymentValidationErrors.premium_required(
        additional_actions: ['contact_sales']
      )

      expect(error.required_actions).to eq(['upgrade_subscription', 'contact_sales'])
    end
  end

  describe '.multiple_requirements' do
    it 'creates PaymentValidationError for multiple missing requirements' do
      missing_requirements = ['stripe_config', 'premium_subscription']
      error = PaymentValidationErrors.multiple_requirements(missing_requirements)

      expect(error).to be_a(PaymentValidationError)
      expect(error.error_type).to eq('multiple_requirements_missing')
      expect(error.required_actions).to eq(['complete_stripe_config', 'complete_premium_subscription'])
      expect(error.user_guidance[:missing_requirements]).to eq(missing_requirements)
    end

    it 'includes additional actions when provided' do
      missing_requirements = ['stripe_config']
      error = PaymentValidationErrors.multiple_requirements(
        missing_requirements,
        additional_actions: ['contact_support']
      )

      expect(error.required_actions).to eq(['complete_stripe_config', 'contact_support'])
    end
  end

  describe '.invalid_payment_configuration' do
    it 'creates PaymentValidationError for invalid payment configuration' do
      error = PaymentValidationErrors.invalid_payment_configuration

      expect(error).to be_a(PaymentValidationError)
      expect(error.error_type).to eq('invalid_payment_configuration')
      expect(error.required_actions).to eq(['review_payment_questions'])
    end

    it 'includes details when provided' do
      details = 'Missing price configuration'
      error = PaymentValidationErrors.invalid_payment_configuration(details: details)

      expect(error.user_guidance[:details]).to eq(details)
    end

    it 'includes additional actions when provided' do
      error = PaymentValidationErrors.invalid_payment_configuration(
        additional_actions: ['validate_prices']
      )

      expect(error.required_actions).to eq(['review_payment_questions', 'validate_prices'])
    end
  end

  describe '.insufficient_permissions' do
    it 'creates PaymentValidationError for insufficient permissions' do
      error = PaymentValidationErrors.insufficient_permissions

      expect(error).to be_a(PaymentValidationError)
      expect(error.error_type).to eq('insufficient_permissions')
      expect(error.required_actions).to eq(['contact_support'])
      expect(error.user_guidance).to eq(PaymentValidationErrors::INSUFFICIENT_PERMISSIONS)
    end

    it 'includes additional actions when provided' do
      error = PaymentValidationErrors.insufficient_permissions(
        additional_actions: ['upgrade_account']
      )

      expect(error.required_actions).to eq(['contact_support', 'upgrade_account'])
    end
  end

  describe '.custom_error' do
    it 'creates custom PaymentValidationError' do
      error = PaymentValidationErrors.custom_error(
        error_type: 'custom_test_error',
        message: 'Custom test message',
        required_actions: ['custom_action'],
        action_url: '/custom_url',
        severity: 'warning'
      )

      expect(error).to be_a(PaymentValidationError)
      expect(error.error_type).to eq('custom_test_error')
      expect(error.message).to eq('Custom test message')
      expect(error.required_actions).to eq(['custom_action'])
      expect(error.user_guidance[:action_url]).to eq('/custom_url')
      expect(error.user_guidance[:severity]).to eq('warning')
    end
  end

  describe '.find_error_definition' do
    it 'finds error definition by type string' do
      definition = PaymentValidationErrors.find_error_definition('stripe_not_configured')
      
      expect(definition).to eq(PaymentValidationErrors::STRIPE_NOT_CONFIGURED)
    end

    it 'finds error definition by type symbol' do
      definition = PaymentValidationErrors.find_error_definition(:premium_subscription_required)
      
      expect(definition).to eq(PaymentValidationErrors::PREMIUM_REQUIRED)
    end

    it 'returns nil for unknown error type' do
      definition = PaymentValidationErrors.find_error_definition('unknown_error')
      
      expect(definition).to be_nil
    end
  end

  describe '.errors_by_category' do
    it 'groups errors by category' do
      grouped_errors = PaymentValidationErrors.errors_by_category

      expect(grouped_errors['payment_setup']).to include(
        PaymentValidationErrors::STRIPE_NOT_CONFIGURED,
        PaymentValidationErrors::MULTIPLE_REQUIREMENTS
      )
      expect(grouped_errors['subscription']).to include(
        PaymentValidationErrors::PREMIUM_REQUIRED
      )
      expect(grouped_errors['configuration']).to include(
        PaymentValidationErrors::INVALID_PAYMENT_CONFIGURATION
      )
      expect(grouped_errors['permissions']).to include(
        PaymentValidationErrors::INSUFFICIENT_PERMISSIONS
      )
    end
  end

  describe '.errors_by_severity' do
    it 'filters errors by severity' do
      error_errors = PaymentValidationErrors.errors_by_severity('error')
      warning_errors = PaymentValidationErrors.errors_by_severity('warning')

      expect(error_errors).to include(
        PaymentValidationErrors::STRIPE_NOT_CONFIGURED,
        PaymentValidationErrors::PREMIUM_REQUIRED,
        PaymentValidationErrors::MULTIPLE_REQUIREMENTS,
        PaymentValidationErrors::INSUFFICIENT_PERMISSIONS
      )
      expect(warning_errors).to include(
        PaymentValidationErrors::INVALID_PAYMENT_CONFIGURATION
      )
    end

    it 'returns empty array for unknown severity' do
      unknown_errors = PaymentValidationErrors.errors_by_severity('unknown')
      
      expect(unknown_errors).to be_empty
    end
  end
end