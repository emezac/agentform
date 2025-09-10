# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PaymentFallbackValidationService, type: :service do
  let(:user) { create(:user, :premium, :with_stripe) }
  let(:form) { create(:form, user: user) }
  let(:service) { described_class.new(form: form) }

  describe '#call' do
    context 'when form has no payment questions' do
      it 'returns success' do
        result = service.call
        
        expect(result).to be_success
        expect(result.message).to eq('Payment validation completed successfully')
        expect(result.validation_status).to eq('passed')
      end
    end

    context 'when form has payment questions' do
      let!(:payment_question) do
        create(:form_question, :payment, form: form, configuration: {
          'amount' => 1000,
          'currency' => 'USD'
        })
      end

      context 'with properly configured user and questions' do
        it 'returns success' do
          result = service.call
          
          expect(result).to be_success
          expect(result.validation_status).to eq('passed')
        end
      end

      context 'when user lacks Stripe configuration' do
        let(:user) { create(:user, :premium) } # No Stripe

        it 'raises stripe_not_configured error' do
          expect { service.call }.to raise_error(PaymentValidationError) do |error|
            expect(error.error_type).to eq('stripe_not_configured')
            expect(error.required_actions).to include('configure_stripe')
          end
        end
      end

      context 'when user lacks Premium subscription' do
        let(:user) { create(:user, :with_stripe) } # No Premium

        it 'raises premium_required error' do
          expect { service.call }.to raise_error(PaymentValidationError) do |error|
            expect(error.error_type).to eq('premium_subscription_required')
            expect(error.required_actions).to include('upgrade_subscription')
          end
        end
      end

      context 'when user lacks both Stripe and Premium' do
        let(:user) { create(:user) } # Basic user

        it 'raises multiple_requirements error' do
          expect { service.call }.to raise_error(PaymentValidationError) do |error|
            expect(error.error_type).to eq('multiple_requirements_missing')
            expect(error.required_actions).to include('configure_stripe', 'upgrade_subscription')
          end
        end
      end

      context 'when payment question is misconfigured' do
        let!(:payment_question) do
          create(:form_question, :payment, form: form, configuration: {
            # Missing amount and currency
          })
        end

        it 'raises invalid_payment_configuration error' do
          expect { service.call }.to raise_error(PaymentValidationError) do |error|
            expect(error.error_type).to eq('invalid_payment_configuration')
            expect(error.user_guidance[:details]).to include(
              match(/Payment question .* must have an amount/),
              match(/Payment question .* must specify a currency/)
            )
          end
        end
      end
    end

    context 'when form has subscription questions' do
      let!(:subscription_question) do
        create(:form_question, :subscription, form: form, configuration: {
          'plans' => [
            { 'name' => 'Basic', 'amount' => 999, 'interval' => 'month' },
            { 'name' => 'Pro', 'amount' => 1999, 'interval' => 'month' }
          ]
        })
      end

      it 'validates successfully with proper configuration' do
        result = service.call
        expect(result).to be_success
      end

      context 'with invalid subscription configuration' do
        let!(:subscription_question) do
          create(:form_question, :subscription, form: form, configuration: {
            'plans' => [
              { 'name' => 'Basic' }, # Missing amount and interval
              { 'name' => 'Pro', 'amount' => 1999 } # Missing interval
            ]
          })
        end

        it 'raises configuration error with specific details' do
          expect { service.call }.to raise_error(PaymentValidationError) do |error|
            expect(error.error_type).to eq('invalid_payment_configuration')
            expect(error.user_guidance[:details]).to include(
              match(/Plan 1 .* is missing amount or interval/),
              match(/Plan 2 .* is missing amount or interval/)
            )
          end
        end
      end
    end

    context 'when form has donation questions' do
      let!(:donation_question) do
        create(:form_question, :donation, form: form, configuration: {
          'suggested_amounts' => [500, 1000, 2500],
          'allow_custom_amount' => true
        })
      end

      it 'validates successfully with proper configuration' do
        result = service.call
        expect(result).to be_success
      end

      context 'with invalid donation configuration' do
        let!(:donation_question) do
          create(:form_question, :donation, form: form, configuration: {
            # No suggested amounts and custom amounts not allowed
            'allow_custom_amount' => false
          })
        end

        it 'raises configuration error' do
          expect { service.call }.to raise_error(PaymentValidationError) do |error|
            expect(error.error_type).to eq('invalid_payment_configuration')
            expect(error.user_guidance[:details]).to include(
              match(/Donation question .* must have suggested amounts or allow custom amounts/)
            )
          end
        end
      end
    end

    context 'when validation service itself fails' do
      before do
        allow(form).to receive(:form_questions).and_raise(StandardError, 'Database error')
      end

      it 'returns a system error result' do
        result = service.call
        
        expect(result).to be_error
        expect(result.message).to eq('Payment validation could not be completed')
        expect(result.errors).to include('validation_system_error')
        expect(result.actions).to include(
          hash_including(type: 'contact_support', url: '/support')
        )
      end
    end
  end

  describe '.validate_form_payment_setup' do
    let!(:payment_question) { create(:form_question, :payment, form: form) }

    it 'creates service instance and calls validation' do
      expect(described_class).to receive(:new).with(form: form).and_call_original
      
      result = described_class.validate_form_payment_setup(form)
      expect(result).to be_success
    end
  end

  describe '.validate_multiple_forms' do
    let(:form1) { create(:form, user: user) }
    let(:form2) { create(:form, user: create(:user)) } # User without proper setup
    let(:forms) { [form1, form2] }

    before do
      create(:form_question, :payment, form: form1)
      create(:form_question, :payment, form: form2)
    end

    it 'validates multiple forms and returns results hash' do
      results = described_class.validate_multiple_forms(forms)
      
      expect(results).to have_key(form1.id)
      expect(results).to have_key(form2.id)
      
      expect(results[form1.id]).to be_success
      expect(results[form2.id]).to include(success: false, error: hash_including(:error_type))
    end

    context 'when a form validation raises unexpected error' do
      before do
        allow_any_instance_of(described_class).to receive(:call).and_raise(StandardError, 'Unexpected error')
      end

      it 'handles the error gracefully' do
        results = described_class.validate_multiple_forms([form1])
        
        expect(results[form1.id]).to include(
          success: false,
          error: hash_including(
            error_type: 'validation_system_error',
            message: 'Validation system error'
          )
        )
      end
    end
  end

  describe 'private methods' do
    let!(:payment_question) { create(:form_question, :payment, form: form) }

    describe '#form_has_payment_questions?' do
      it 'returns true when form has payment questions' do
        expect(service.send(:form_has_payment_questions?)).to be true
      end

      it 'caches the result' do
        expect(form.form_questions).to receive(:where).once.and_call_original
        
        2.times { service.send(:form_has_payment_questions?) }
      end
    end

    describe '#user_has_stripe_configured?' do
      context 'with properly configured Stripe user' do
        it 'returns true' do
          expect(service.send(:user_has_stripe_configured?)).to be true
        end
      end

      context 'with user missing Stripe configuration' do
        let(:user) { create(:user, stripe_account_id: nil) }

        it 'returns false' do
          expect(service.send(:user_has_stripe_configured?)).to be false
        end
      end
    end

    describe '#user_has_premium_access?' do
      context 'with premium user' do
        it 'returns true' do
          expect(service.send(:user_has_premium_access?)).to be true
        end
      end

      context 'with basic user' do
        let(:user) { create(:user) }

        it 'returns false' do
          expect(service.send(:user_has_premium_access?)).to be false
        end
      end

      context 'with pro subscription tier' do
        let(:user) { create(:user, subscription_tier: 'pro') }

        it 'returns true' do
          expect(service.send(:user_has_premium_access?)).to be true
        end
      end
    end
  end

  describe 'error logging' do
    let!(:payment_question) { create(:form_question, :payment, form: form) }
    let(:user) { create(:user) } # User without proper setup

    it 'logs validation steps' do
      expect(Rails.logger).to receive(:info).with("Starting fallback payment validation for form #{form.id}")
      expect(Rails.logger).to receive(:debug).with("Form has payment questions, validating requirements")
      expect(Rails.logger).to receive(:debug).with("Validating user payment setup")
      expect(Rails.logger).to receive(:debug).with("Validating payment question configuration")

      expect { service.call }.to raise_error(PaymentValidationError)
    end
  end
end