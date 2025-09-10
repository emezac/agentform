# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PaymentErrorHelper, type: :helper do
  describe '#format_payment_error' do
    let(:error) { PaymentValidationErrors.stripe_not_configured }

    it 'formats PaymentValidationError correctly' do
      formatted = helper.format_payment_error(error)
      
      expect(formatted).to include(
        type: 'stripe_not_configured',
        message: error.message,
        description: error.user_guidance[:description],
        severity: 'error',
        actionable: true,
        help_available: true
      )
    end

    it 'includes primary action when available' do
      formatted = helper.format_payment_error(error)
      
      expect(formatted[:primary_action]).to include(
        text: 'Configure Stripe',
        url: '/stripe_settings',
        style: 'primary'
      )
    end

    it 'includes additional actions' do
      formatted = helper.format_payment_error(error)
      
      expect(formatted[:additional_actions]).to include(
        hash_including(text: 'Get Help', action: 'show_help'),
        hash_including(text: 'Contact Support', action: 'contact_support')
      )
    end

    it 'returns nil for non-PaymentValidationError objects' do
      expect(helper.format_payment_error('not an error')).to be_nil
      expect(helper.format_payment_error(nil)).to be_nil
    end
  end

  describe '#payment_error_flash' do
    let(:error) { PaymentValidationErrors.stripe_not_configured }

    it 'renders payment error flash partial' do
      expect(helper).to receive(:render).with(
        partial: 'shared/payment_error_flash',
        locals: hash_including(:error)
      )
      
      helper.payment_error_flash(error)
    end

    it 'passes through options to partial' do
      expect(helper).to receive(:render).with(
        partial: 'shared/payment_error_flash',
        locals: hash_including(:error, custom_option: 'value')
      )
      
      helper.payment_error_flash(error, custom_option: 'value')
    end

    it 'returns nil for nil error' do
      expect(helper.payment_error_flash(nil)).to be_nil
    end
  end

  describe '#payment_setup_guidance' do
    let(:error) { PaymentValidationErrors.premium_required }

    it 'renders payment setup guidance partial with defaults' do
      expect(helper).to receive(:render).with(
        partial: 'shared/payment_setup_guidance',
        locals: {
          error: error,
          show_actions: true,
          context: 'general',
          compact: false
        }
      )
      
      helper.payment_setup_guidance(error)
    end

    it 'accepts custom options' do
      expect(helper).to receive(:render).with(
        partial: 'shared/payment_setup_guidance',
        locals: {
          error: error,
          show_actions: false,
          context: 'form_editor',
          compact: true
        }
      )
      
      helper.payment_setup_guidance(error, show_actions: false, context: 'form_editor', compact: true)
    end
  end

  describe '#payment_setup_required_button' do
    let(:error) { PaymentValidationErrors.multiple_requirements(['stripe_config', 'premium']) }

    it 'renders payment setup required button partial with defaults' do
      expect(helper).to receive(:render).with(
        partial: 'shared/payment_setup_required_button',
        locals: {
          error: error,
          button_text: 'Complete Setup to Publish',
          button_class: 'btn-primary',
          show_icon: true
        }
      )
      
      helper.payment_setup_required_button(error)
    end

    it 'accepts custom button options' do
      expect(helper).to receive(:render).with(
        partial: 'shared/payment_setup_required_button',
        locals: {
          error: error,
          button_text: 'Custom Text',
          button_class: 'btn-secondary',
          show_icon: false
        }
      )
      
      helper.payment_setup_required_button(error, 
        button_text: 'Custom Text', 
        button_class: 'btn-secondary', 
        show_icon: false
      )
    end
  end

  describe '#payment_error_severity_classes' do
    it 'returns correct classes for error severity' do
      expect(helper.payment_error_severity_classes('error')).to eq('bg-red-50 border-red-200 text-red-800')
    end

    it 'returns correct classes for warning severity' do
      expect(helper.payment_error_severity_classes('warning')).to eq('bg-yellow-50 border-yellow-200 text-yellow-800')
    end

    it 'returns correct classes for info severity' do
      expect(helper.payment_error_severity_classes('info')).to eq('bg-blue-50 border-blue-200 text-blue-800')
    end

    it 'returns default classes for unknown severity' do
      expect(helper.payment_error_severity_classes('unknown')).to eq('bg-gray-50 border-gray-200 text-gray-800')
    end
  end

  describe '#payment_error_icon' do
    it 'returns correct icon for stripe_not_configured' do
      expect(helper.payment_error_icon('stripe_not_configured')).to eq('credit-card')
    end

    it 'returns correct icon for premium_subscription_required' do
      expect(helper.payment_error_icon('premium_subscription_required')).to eq('star')
    end

    it 'returns correct icon for multiple_requirements_missing' do
      expect(helper.payment_error_icon('multiple_requirements_missing')).to eq('exclamation-triangle')
    end

    it 'returns default icon for unknown error type' do
      expect(helper.payment_error_icon('unknown_error')).to eq('exclamation-circle')
    end
  end

  describe '#humanize_payment_requirement' do
    it 'humanizes stripe_configuration' do
      expect(helper.humanize_payment_requirement('stripe_configuration')).to eq('Stripe Configuration')
    end

    it 'humanizes premium_subscription' do
      expect(helper.humanize_payment_requirement('premium_subscription')).to eq('Premium Subscription')
    end

    it 'humanizes payment_setup' do
      expect(helper.humanize_payment_requirement('payment_setup')).to eq('Payment Setup')
    end

    it 'falls back to humanize for unknown requirements' do
      expect(helper.humanize_payment_requirement('custom_requirement')).to eq('Custom requirement')
    end
  end

  describe '#estimated_setup_time' do
    it 'returns correct time for stripe_not_configured' do
      expect(helper.estimated_setup_time('stripe_not_configured')).to eq('5-10 minutes')
    end

    it 'returns correct time for premium_subscription_required' do
      expect(helper.estimated_setup_time('premium_subscription_required')).to eq('2-3 minutes')
    end

    it 'returns correct time for multiple_requirements_missing' do
      expect(helper.estimated_setup_time('multiple_requirements_missing')).to eq('10-15 minutes')
    end

    it 'returns default for unknown error type' do
      expect(helper.estimated_setup_time('unknown_error')).to eq('Varies')
    end
  end

  describe '#help_available_for_error?' do
    it 'returns true for supported error types' do
      %w[stripe_not_configured premium_subscription_required multiple_requirements_missing invalid_payment_configuration].each do |error_type|
        expect(helper.help_available_for_error?(error_type)).to be true
      end
    end

    it 'returns false for unsupported error types' do
      expect(helper.help_available_for_error?('unknown_error')).to be false
      expect(helper.help_available_for_error?('insufficient_permissions')).to be false
    end
  end

  describe '#help_url_for_error' do
    it 'returns correct URL for stripe_not_configured' do
      expect(helper.help_url_for_error('stripe_not_configured')).to eq('/help/stripe-setup')
    end

    it 'returns correct URL for premium_subscription_required' do
      expect(helper.help_url_for_error('premium_subscription_required')).to eq('/help/premium-features')
    end

    it 'returns default URL for unknown error type' do
      expect(helper.help_url_for_error('unknown_error')).to eq('/help/payment-setup')
    end
  end

  describe '#payment_error_analytics_data' do
    let(:error) { PaymentValidationErrors.stripe_not_configured }

    it 'returns structured analytics data' do
      data = helper.payment_error_analytics_data(error)
      
      expect(data).to include(
        error_type: 'stripe_not_configured',
        error_category: 'payment_setup',
        error_severity: 'error',
        has_actions: true,
        action_count: 1
      )
      expect(data[:timestamp]).to be_present
    end

    it 'returns empty hash for nil error' do
      expect(helper.payment_error_analytics_data(nil)).to eq({})
    end
  end

  describe '#payment_error_recovery_data' do
    let(:error) { PaymentValidationErrors.premium_required }
    let(:context) { { form_id: 123, user_id: 456 } }

    it 'returns structured recovery data' do
      data = helper.payment_error_recovery_data(error, context)
      
      expect(data).to include(
        error_type: 'premium_subscription_required',
        recovery_available: true,
        estimated_time: '2-3 minutes',
        context: context,
        help_url: '/help/premium-features',
        support_contact: 'support@agentform.com'
      )
    end

    it 'returns empty hash for nil error' do
      expect(helper.payment_error_recovery_data(nil)).to eq({})
    end
  end

  describe '#payment_error_education' do
    it 'renders education partial for stripe_not_configured' do
      expect(helper).to receive(:render).with(
        partial: 'shared/payment_error_education',
        locals: {
          content: hash_including(
            title: 'About Stripe Integration',
            description: match(/Stripe is a secure payment processor/),
            benefits: array_including(match(/PCI compliance/)),
            setup_time: '5-10 minutes'
          )
        }
      )
      
      helper.payment_error_education('stripe_not_configured')
    end

    it 'renders education partial for premium_subscription_required' do
      expect(helper).to receive(:render).with(
        partial: 'shared/payment_error_education',
        locals: {
          content: hash_including(
            title: 'Premium Features',
            description: match(/Payment functionality is included/),
            benefits: array_including(match(/Unlimited payment forms/)),
            setup_time: '2-3 minutes'
          )
        }
      )
      
      helper.payment_error_education('premium_subscription_required')
    end

    it 'renders default education for unknown error type' do
      expect(helper).to receive(:render).with(
        partial: 'shared/payment_error_education',
        locals: {
          content: hash_including(
            title: 'Payment Setup',
            description: match(/Complete payment setup/),
            setup_time: 'Varies'
          )
        }
      )
      
      helper.payment_error_education('unknown_error')
    end
  end
end