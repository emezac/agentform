# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FormPublishValidationService, type: :service do
  let(:user) { create(:user, subscription_tier: 'premium') }
  let(:form) { create(:form, user: user) }
  let(:service) { described_class.new(form: form) }

  describe '#call' do
    context 'with valid inputs' do
      it 'returns success for form without payment questions' do
        result = service.call

        expect(result).to be_success
        expect(result.result[:can_publish]).to be true
        expect(result.result[:validation_errors]).to be_empty
        expect(result.result[:required_actions]).to be_empty
      end
    end

    context 'with invalid inputs' do
      let(:service) { described_class.new(form: nil) }

      it 'returns failure when form is nil' do
        result = service.call

        expect(result).to be_failure
        expect(result.errors.full_messages).to include('Form is required')
      end

      it 'returns failure when form is not a Form instance' do
        service = described_class.new(form: 'not_a_form')
        result = service.call

        expect(result).to be_failure
        expect(result.errors.full_messages).to include('Form must be a Form instance')
      end
    end

    context 'with payment questions' do
      let!(:payment_question) do
        create(:form_question, 
               form: form, 
               question_type: 'payment',
               question_config: {
                 'amount' => '29.99',
                 'currency' => 'USD',
                 'description' => 'Test payment'
               })
      end

      before do
        allow(form).to receive(:has_payment_questions?).and_return(true)
        allow(form).to receive(:payment_questions).and_return([payment_question])
      end

      context 'when user has complete payment setup' do
        before do
          allow(user).to receive(:stripe_configured?).and_return(true)
          allow(user).to receive(:premium?).and_return(true)
          allow(user).to receive(:can_accept_payments?).and_return(true)
        end

        it 'allows publishing when all requirements are met' do
          result = service.call

          expect(result).to be_success
          expect(result.result[:can_publish]).to be true
          expect(result.result[:validation_errors]).to be_empty
        end
      end

      context 'when user lacks Stripe configuration' do
        before do
          allow(user).to receive(:stripe_configured?).and_return(false)
          allow(user).to receive(:premium?).and_return(true)
          allow(user).to receive(:can_accept_payments?).and_return(false)
        end

        it 'prevents publishing and provides Stripe setup guidance' do
          result = service.call

          expect(result).to be_success
          expect(result.result[:can_publish]).to be false
          
          stripe_error = result.result[:validation_errors].find { |e| e[:type] == 'stripe_not_configured' }
          expect(stripe_error).to be_present
          expect(stripe_error[:title]).to eq('Stripe Configuration Required')
          
          stripe_action = result.result[:required_actions].find { |a| a[:type] == 'stripe_setup' }
          expect(stripe_action).to be_present
          expect(stripe_action[:action_url]).to eq('/stripe_settings')
        end
      end

      context 'when user lacks Premium subscription' do
        let(:user) { create(:user, subscription_tier: 'basic') }

        before do
          allow(user).to receive(:stripe_configured?).and_return(true)
          allow(user).to receive(:premium?).and_return(false)
          allow(user).to receive(:can_accept_payments?).and_return(false)
        end

        it 'prevents publishing and provides subscription upgrade guidance' do
          result = service.call

          expect(result).to be_success
          expect(result.result[:can_publish]).to be false
          
          premium_error = result.result[:validation_errors].find { |e| e[:type] == 'premium_subscription_required' }
          expect(premium_error).to be_present
          expect(premium_error[:title]).to eq('Premium Subscription Required')
          
          upgrade_action = result.result[:required_actions].find { |a| a[:type] == 'subscription_upgrade' }
          expect(upgrade_action).to be_present
          expect(upgrade_action[:action_url]).to eq('/subscription_management')
        end
      end

      context 'when payment question configuration is missing' do
        let!(:payment_question) do
          create(:form_question, 
                 form: form, 
                 question_type: 'payment',
                 question_config: nil)
        end

        before do
          allow(user).to receive(:stripe_configured?).and_return(true)
          allow(user).to receive(:premium?).and_return(true)
          allow(user).to receive(:can_accept_payments?).and_return(true)
        end

        it 'prevents publishing and provides configuration guidance' do
          result = service.call

          expect(result).to be_success
          expect(result.result[:can_publish]).to be false
          
          config_error = result.result[:validation_errors].find { |e| e[:type] == 'payment_question_configuration' }
          expect(config_error).to be_present
          expect(config_error[:question_id]).to eq(payment_question.id)
          
          config_action = result.result[:required_actions].find { |a| a[:type] == 'configure_payment_question' }
          expect(config_action).to be_present
          expect(config_action[:action_url]).to include("/forms/#{form.id}/questions/#{payment_question.id}/edit")
        end
      end

      context 'when payment question fields are missing' do
        let!(:payment_question) do
          create(:form_question, 
                 form: form, 
                 question_type: 'payment',
                 question_config: {
                   'amount' => '',
                   'currency' => 'USD'
                   # missing description
                 })
        end

        before do
          allow(user).to receive(:stripe_configured?).and_return(true)
          allow(user).to receive(:premium?).and_return(true)
          allow(user).to receive(:can_accept_payments?).and_return(true)
        end

        it 'prevents publishing and provides field completion guidance' do
          result = service.call

          expect(result).to be_success
          expect(result.result[:can_publish]).to be false
          
          fields_error = result.result[:validation_errors].find { |e| e[:type] == 'payment_question_fields' }
          expect(fields_error).to be_present
          expect(fields_error[:details]).to include('Missing amount', 'Missing description')
          
          fields_action = result.result[:required_actions].find { |a| a[:type] == 'complete_payment_fields' }
          expect(fields_action).to be_present
        end
      end

      context 'when multiple requirements are missing' do
        let(:user) { create(:user, subscription_tier: 'basic') }
        let!(:payment_question) do
          create(:form_question, 
                 form: form, 
                 question_type: 'payment',
                 question_config: nil)
        end

        before do
          allow(user).to receive(:stripe_configured?).and_return(false)
          allow(user).to receive(:premium?).and_return(false)
          allow(user).to receive(:can_accept_payments?).and_return(false)
        end

        it 'prevents publishing and provides all necessary guidance' do
          result = service.call

          expect(result).to be_success
          expect(result.result[:can_publish]).to be false
          expect(result.result[:validation_errors].length).to be >= 3
          expect(result.result[:required_actions].length).to be >= 3
          
          # Check for all expected error types
          error_types = result.result[:validation_errors].map { |e| e[:type] }
          expect(error_types).to include('stripe_not_configured')
          expect(error_types).to include('premium_subscription_required')
          expect(error_types).to include('payment_question_configuration')
        end
      end
    end

    context 'integration with PaymentReadinessChecker' do
      let!(:payment_question) do
        create(:form_question, 
               form: form, 
               question_type: 'payment',
               question_config: {
                 'amount' => '29.99',
                 'currency' => 'USD',
                 'description' => 'Test payment'
               })
      end

      before do
        allow(form).to receive(:has_payment_questions?).and_return(true)
        allow(form).to receive(:payment_questions).and_return([payment_question])
      end

      it 'integrates with PaymentReadinessChecker for comprehensive validation' do
        # Mock PaymentReadinessChecker to return failure
        mock_checker = instance_double(PaymentReadinessChecker)
        allow(PaymentReadinessChecker).to receive(:new).and_return(mock_checker)
        allow(mock_checker).to receive(:call).and_return(mock_checker)
        allow(mock_checker).to receive(:failure?).and_return(true)
        allow(mock_checker).to receive(:result).and_return({
          errors: [{ type: 'test_error', message: 'Test error from checker' }],
          actions: [{ type: 'test_action', title: 'Test action' }]
        })

        result = service.call

        expect(result).to be_success
        expect(result.result[:can_publish]).to be false
        expect(result.result[:validation_errors]).to include(
          hash_including(type: 'test_error', message: 'Test error from checker')
        )
        expect(result.result[:required_actions]).to include(
          hash_including(type: 'test_action', title: 'Test action')
        )
      end
    end

    context 'context tracking' do
      let!(:payment_question1) do
        create(:form_question, form: form, question_type: 'payment')
      end
      let!(:payment_question2) do
        create(:form_question, form: form, question_type: 'payment')
      end

      before do
        allow(form).to receive(:has_payment_questions?).and_return(true)
        allow(form).to receive(:payment_questions).and_return([payment_question1, payment_question2])
      end

      it 'tracks context information during validation' do
        result = service.call

        expect(result.get_context(:payment_questions_count)).to eq(2)
        expect(result.get_context(:validation_errors_count)).to be_present
      end
    end
  end

  describe 'private methods' do
    describe '#validate_payment_question_fields' do
      let(:question) { build(:form_question, question_type: 'payment') }
      let(:validation_results) { { validation_errors: [] } }

      context 'with complete configuration' do
        before do
          question.question_config = {
            'amount' => '29.99',
            'currency' => 'USD',
            'description' => 'Complete payment configuration'
          }
        end

        it 'does not add validation errors' do
          service.send(:validate_payment_question_fields, question, validation_results)
          expect(validation_results[:validation_errors]).to be_empty
        end
      end

      context 'with missing required fields' do
        before do
          question.question_config = {
            'amount' => '',
            'currency' => 'USD'
            # missing description
          }
        end

        it 'adds validation errors for missing fields' do
          service.send(:validate_payment_question_fields, question, validation_results)
          
          error = validation_results[:validation_errors].first
          expect(error[:type]).to eq('payment_question_fields')
          expect(error[:details]).to include('Missing amount', 'Missing description')
        end
      end
    end

    describe 'action generation methods' do
      it 'generates stripe setup action with correct attributes' do
        action = service.send(:generate_stripe_setup_action)
        
        expect(action[:type]).to eq('stripe_setup')
        expect(action[:title]).to eq('Configure Stripe Payments')
        expect(action[:action_url]).to eq('/stripe_settings')
        expect(action[:priority]).to eq('high')
        expect(action[:icon]).to eq('credit-card')
      end

      it 'generates subscription upgrade action with correct attributes' do
        action = service.send(:generate_subscription_upgrade_action)
        
        expect(action[:type]).to eq('subscription_upgrade')
        expect(action[:title]).to eq('Upgrade to Premium')
        expect(action[:action_url]).to eq('/subscription_management')
        expect(action[:priority]).to eq('high')
        expect(action[:icon]).to eq('star')
      end
    end
  end
end