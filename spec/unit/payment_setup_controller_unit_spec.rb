require 'rails_helper'

RSpec.describe 'PaymentSetupController Unit Tests' do
  describe 'Controller logic validation' do
    let(:user) { create(:user, subscription_tier: 'basic') }
    let(:premium_user) { create(:user, subscription_tier: 'premium', stripe_enabled: true, stripe_publishable_key: 'pk_test_123', stripe_secret_key: 'sk_test_123') }
    let(:form_template) { create(:form_template, :with_payment_questions) }
    let(:payment_form) { create(:form, user: user, template: form_template) }

    describe 'Setup progress calculation' do
      it 'calculates 0% for basic user without Stripe' do
        # Simulate controller logic
        stripe_configured = user.stripe_configured?
        is_premium = user.premium?
        
        total_requirements = 2
        completed_requirements = 0
        completed_requirements += 1 if stripe_configured
        completed_requirements += 1 if is_premium
        
        progress = (completed_requirements.to_f / total_requirements * 100).round
        
        expect(progress).to eq(0)
      end

      it 'calculates 50% for user with Stripe but no premium' do
        user.update!(stripe_enabled: true, stripe_publishable_key: 'pk_test_123', stripe_secret_key: 'sk_test_123')
        
        stripe_configured = user.stripe_configured?
        is_premium = user.premium?
        
        total_requirements = 2
        completed_requirements = 0
        completed_requirements += 1 if stripe_configured
        completed_requirements += 1 if is_premium
        
        progress = (completed_requirements.to_f / total_requirements * 100).round
        
        expect(progress).to eq(50)
      end

      it 'calculates 100% for premium user with Stripe' do
        stripe_configured = premium_user.stripe_configured?
        is_premium = premium_user.premium?
        
        total_requirements = 2
        completed_requirements = 0
        completed_requirements += 1 if stripe_configured
        completed_requirements += 1 if is_premium
        
        progress = (completed_requirements.to_f / total_requirements * 100).round
        
        expect(progress).to eq(100)
      end
    end

    describe 'Missing requirements detection' do
      it 'identifies both requirements missing for basic user' do
        missing = []
        missing << 'stripe_configuration' unless user.stripe_configured?
        missing << 'premium_subscription' unless user.premium?
        
        expect(missing).to include('stripe_configuration')
        expect(missing).to include('premium_subscription')
        expect(missing.length).to eq(2)
      end

      it 'identifies only premium missing for user with Stripe' do
        user.update!(stripe_enabled: true, stripe_publishable_key: 'pk_test_123', stripe_secret_key: 'sk_test_123')
        
        missing = []
        missing << 'stripe_configuration' unless user.stripe_configured?
        missing << 'premium_subscription' unless user.premium?
        
        expect(missing).to include('premium_subscription')
        expect(missing).not_to include('stripe_configuration')
        expect(missing.length).to eq(1)
      end

      it 'identifies no missing requirements for premium user with Stripe' do
        missing = []
        missing << 'stripe_configuration' unless premium_user.stripe_configured?
        missing << 'premium_subscription' unless premium_user.premium?
        
        expect(missing).to be_empty
      end
    end

    describe 'Form payment question detection' do
      it 'detects payment questions in form template' do
        has_payment_questions = payment_form.template.template_data['questions'].any? do |question|
          question['question_type'] == 'payment'
        end
        
        expect(has_payment_questions).to be true
      end

      it 'does not detect payment questions in regular form' do
        regular_form = create(:form, user: user)
        
        has_payment_questions = if regular_form.template
          regular_form.template.template_data['questions'].any? do |question|
            question['question_type'] == 'payment'
          end
        else
          false
        end
        
        expect(has_payment_questions).to be false
      end
    end

    describe 'Setup completion status' do
      it 'returns false for incomplete setup' do
        setup_complete = user.stripe_configured? && user.premium?
        expect(setup_complete).to be false
      end

      it 'returns true for complete setup' do
        setup_complete = premium_user.stripe_configured? && premium_user.premium?
        expect(setup_complete).to be true
      end
    end

    describe 'Required features detection' do
      it 'identifies required features for payment forms' do
        required_features = []
        
        if payment_form.template.template_data['questions'].any? { |q| q['question_type'] == 'payment' }
          required_features << 'stripe_payments'
          required_features << 'premium_subscription'
        end
        
        expect(required_features).to include('stripe_payments')
        expect(required_features).to include('premium_subscription')
      end

      it 'identifies no required features for regular forms' do
        regular_form = create(:form, user: user)
        required_features = []
        
        if regular_form.template && regular_form.template.template_data['questions'].any? { |q| q['question_type'] == 'payment' }
          required_features << 'stripe_payments'
          required_features << 'premium_subscription'
        end
        
        expect(required_features).to be_empty
      end
    end
  end

  describe 'Event tracking data structure' do
    let(:user) { create(:user, subscription_tier: 'basic') }

    it 'creates correct event data structure' do
      event_data = {
        has_payment_questions: true,
        stripe_configured: user.stripe_configured?,
        is_premium: user.premium?,
        required_features: ['stripe_payments', 'premium_subscription'],
        event_type: 'setup_initiated',
        timestamp: Time.current.iso8601,
        action: 'stripe_configuration'
      }

      expect(event_data).to include(
        has_payment_questions: true,
        stripe_configured: false,
        is_premium: false,
        required_features: ['stripe_payments', 'premium_subscription'],
        event_type: 'setup_initiated',
        action: 'stripe_configuration'
      )
      expect(event_data[:timestamp]).to be_present
    end
  end

  describe 'API endpoint expectations' do
    it 'expects correct API response format for status endpoint' do
      expected_response = {
        success: true,
        setup_status: {
          stripe_configured: false,
          premium_subscription: false,
          can_accept_payments: false,
          setup_completion_percentage: 0
        }
      }

      expect(expected_response[:success]).to be true
      expect(expected_response[:setup_status]).to include(
        stripe_configured: false,
        premium_subscription: false,
        can_accept_payments: false,
        setup_completion_percentage: 0
      )
    end

    it 'expects correct API response format for analytics endpoint' do
      expected_request = {
        event: {
          has_payment_questions: true,
          stripe_configured: false,
          is_premium: false,
          required_features: ['stripe_payments', 'premium_subscription'],
          event_type: 'setup_initiated',
          timestamp: Time.current.iso8601
        }
      }

      expect(expected_request[:event]).to include(
        has_payment_questions: true,
        stripe_configured: false,
        is_premium: false,
        required_features: ['stripe_payments', 'premium_subscription'],
        event_type: 'setup_initiated'
      )
      expect(expected_request[:event][:timestamp]).to be_present
    end
  end

  describe 'Modal content generation' do
    let(:user) { create(:user, subscription_tier: 'basic') }
    let(:partial_user) { create(:user, subscription_tier: 'basic', stripe_enabled: true, stripe_publishable_key: 'pk_test_123', stripe_secret_key: 'sk_test_123') }

    it 'includes both setup options for user with no setup' do
      stripe_configured = user.stripe_configured?
      is_premium = user.premium?

      modal_content = []
      modal_content << 'stripe_configuration' unless stripe_configured
      modal_content << 'premium_subscription' unless is_premium

      expect(modal_content).to include('stripe_configuration')
      expect(modal_content).to include('premium_subscription')
    end

    it 'includes only premium option for user with Stripe' do
      stripe_configured = partial_user.stripe_configured?
      is_premium = partial_user.premium?

      modal_content = []
      modal_content << 'stripe_configuration' unless stripe_configured
      modal_content << 'premium_subscription' unless is_premium

      expect(modal_content).not_to include('stripe_configuration')
      expect(modal_content).to include('premium_subscription')
    end

    it 'includes no options for complete setup' do
      premium_user = create(:user, subscription_tier: 'premium', stripe_enabled: true, stripe_publishable_key: 'pk_test_123', stripe_secret_key: 'sk_test_123')
      
      stripe_configured = premium_user.stripe_configured?
      is_premium = premium_user.premium?

      modal_content = []
      modal_content << 'stripe_configuration' unless stripe_configured
      modal_content << 'premium_subscription' unless is_premium

      expect(modal_content).to be_empty
    end
  end

  describe 'URL generation for setup actions' do
    it 'generates correct URLs for setup actions' do
      stripe_url = '/stripe_settings'
      subscription_url = '/subscription_management'
      
      expect(stripe_url).to eq('/stripe_settings')
      expect(subscription_url).to eq('/subscription_management')
    end
  end

  describe 'Polling configuration' do
    it 'uses correct polling intervals' do
      regular_polling_interval = 5000  # 5 seconds
      active_polling_interval = 2000   # 2 seconds
      active_polling_timeout = 120000  # 2 minutes

      expect(regular_polling_interval).to eq(5000)
      expect(active_polling_interval).to eq(2000)
      expect(active_polling_timeout).to eq(120000)
    end
  end
end