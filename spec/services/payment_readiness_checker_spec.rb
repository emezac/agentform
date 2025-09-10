# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PaymentReadinessChecker, type: :service do
  let(:user) { create(:user, subscription_tier: 'premium') }
  let(:form) { create(:form, user: user) }
  let(:service) { described_class.new(form: form) }

  describe '#call' do
    context 'with valid inputs' do
      it 'returns success for form without payment questions' do
        # Ensure form has a name and at least one question
        form.update!(name: 'Test Form')
        create(:form_question, form: form, question_type: 'text_short', title: 'Test Question')
        
        result = service.call

        expect(result).to be_success
        expect(result.result[:ready]).to be true
        expect(result.result[:errors]).to be_empty
        expect(result.result[:actions]).to be_empty
      end

      it 'derives user from form when user not provided' do
        result = service.call

        expect(result).to be_success
        expect(service.user).to eq(form.user)
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

      context 'when all requirements are met' do
        before do
          allow(user).to receive(:premium?).and_return(true)
          allow(StripeConfigurationChecker).to receive(:configuration_status)
            .and_return({ configured: true })
          allow(user).to receive(:stripe_webhook_secret).and_return('whsec_test')
        end

        it 'returns ready status' do
          result = service.call

          expect(result).to be_success
          expect(result.result[:ready]).to be true
          expect(result.result[:errors]).to be_empty
          expect(result.result[:actions]).to be_empty
        end

        it 'tracks all performed checks' do
          result = service.call

          expected_checks = [
            'payment_questions_presence',
            'user_subscription_status',
            'stripe_configuration',
            'payment_questions_configuration',
            'webhook_configuration',
            'form_publish_eligibility'
          ]

          expect(result.result[:checks_performed]).to match_array(expected_checks)
        end
      end

      context 'when user lacks premium subscription' do
        let(:user) { create(:user, subscription_tier: 'basic') }

        it 'identifies premium subscription requirement' do
          result = service.call

          expect(result).to be_success
          expect(result.result[:ready]).to be false
          
          premium_error = result.result[:errors].find { |e| e[:type] == 'premium_subscription_required' }
          expect(premium_error).to be_present
          expect(premium_error[:severity]).to eq('high')
          expect(premium_error[:current_tier]).to eq('basic')
          expect(premium_error[:required_tier]).to eq('premium')
        end

        it 'generates subscription upgrade action' do
          result = service.call

          upgrade_action = result.result[:actions].find { |a| a[:type] == 'upgrade_subscription' }
          expect(upgrade_action).to be_present
          expect(upgrade_action[:title]).to eq('Upgrade to Premium')
          expect(upgrade_action[:url]).to eq('/subscription_management')
          expect(upgrade_action[:priority]).to eq('high')
        end
      end

      context 'when Stripe is not configured' do
        before do
          allow(user).to receive(:premium?).and_return(true)
          allow(StripeConfigurationChecker).to receive(:configuration_status)
            .and_return({ 
              configured: false, 
              missing_elements: ['publishable_key', 'secret_key'] 
            })
        end

        it 'identifies Stripe configuration requirement' do
          result = service.call

          expect(result).to be_success
          expect(result.result[:ready]).to be false
          
          stripe_error = result.result[:errors].find { |e| e[:type] == 'stripe_not_configured' }
          expect(stripe_error).to be_present
          expect(stripe_error[:severity]).to eq('high')
          expect(stripe_error[:missing_elements]).to eq(['publishable_key', 'secret_key'])
          expect(stripe_error[:configuration_url]).to eq('/stripe_settings')
        end

        it 'generates Stripe configuration action' do
          result = service.call

          stripe_action = result.result[:actions].find { |a| a[:type] == 'configure_stripe' }
          expect(stripe_action).to be_present
          expect(stripe_action[:title]).to eq('Configure Stripe')
          expect(stripe_action[:url]).to eq('/stripe_settings')
          expect(stripe_action[:priority]).to eq('high')
        end
      end

      context 'when payment question configuration is invalid' do
        let!(:invalid_payment_question) do
          create(:form_question, 
                 form: form, 
                 question_type: 'payment',
                 question_config: {
                   'amount' => 'invalid',
                   'currency' => 'INVALID',
                   'description' => 'a' * 600 # too long
                 })
        end

        before do
          allow(form).to receive(:payment_questions).and_return([invalid_payment_question])
          allow(user).to receive(:premium?).and_return(true)
          allow(StripeConfigurationChecker).to receive(:configuration_status)
            .and_return({ configured: true })
        end

        it 'identifies payment question configuration issues' do
          result = service.call

          expect(result).to be_success
          expect(result.result[:ready]).to be false
          
          config_errors = result.result[:errors].select { |e| e[:type] == 'payment_question_invalid' }
          expect(config_errors).not_to be_empty
          
          config_error = config_errors.first
          expect(config_error[:question_id]).to eq(invalid_payment_question.id)
          expect(config_error[:severity]).to eq('high')
        end

        it 'generates payment question fix action' do
          result = service.call

          fix_action = result.result[:actions].find { |a| a[:type] == 'fix_payment_questions' }
          expect(fix_action).to be_present
          expect(fix_action[:title]).to eq('Fix Payment Questions')
          expect(fix_action[:url]).to eq("/forms/#{form.id}/edit")
          expect(fix_action[:priority]).to eq('high')
        end
      end

      context 'when webhook configuration is incomplete' do
        before do
          allow(user).to receive(:premium?).and_return(true)
          allow(StripeConfigurationChecker).to receive(:configuration_status)
            .and_return({ configured: true })
          allow(user).to receive(:stripe_webhook_secret).and_return(nil)
        end

        it 'identifies webhook configuration requirement' do
          result = service.call

          expect(result).to be_success
          expect(result.result[:ready]).to be false
          
          webhook_error = result.result[:errors].find { |e| e[:type] == 'webhook_configuration_incomplete' }
          expect(webhook_error).to be_present
          expect(webhook_error[:severity]).to eq('medium')
          expect(webhook_error[:issues]).to include('Webhook secret not configured')
        end

        it 'generates webhook configuration action' do
          result = service.call

          webhook_action = result.result[:actions].find { |a| a[:type] == 'configure_webhooks' }
          expect(webhook_action).to be_present
          expect(webhook_action[:title]).to eq('Configure Webhooks')
          expect(webhook_action[:url]).to eq('/stripe_settings/webhooks')
          expect(webhook_action[:priority]).to eq('medium')
        end
      end
    end

    context 'form publish eligibility checks' do
      context 'when form name is missing' do
        before do
          form.update_column(:name, '')
        end

        it 'identifies form name requirement' do
          result = service.call

          expect(result).to be_success
          expect(result.result[:ready]).to be false
          
          name_error = result.result[:errors].find { |e| e[:type] == 'form_name_missing' }
          expect(name_error).to be_present
          expect(name_error[:severity]).to eq('high')
        end

        it 'generates add form name action' do
          result = service.call

          name_action = result.result[:actions].find { |a| a[:type] == 'add_form_name' }
          expect(name_action).to be_present
          expect(name_action[:title]).to eq('Add Form Name')
          expect(name_action[:url]).to eq("/forms/#{form.id}/edit")
        end
      end

      context 'when form has no questions' do
        before do
          form.form_questions.destroy_all
        end

        it 'identifies no questions requirement' do
          result = service.call

          expect(result).to be_success
          expect(result.result[:ready]).to be false
          
          questions_error = result.result[:errors].find { |e| e[:type] == 'no_questions' }
          expect(questions_error).to be_present
          expect(questions_error[:severity]).to eq('high')
        end

        it 'generates add questions action' do
          result = service.call

          questions_action = result.result[:actions].find { |a| a[:type] == 'add_questions' }
          expect(questions_action).to be_present
          expect(questions_action[:title]).to eq('Add Questions')
          expect(questions_action[:url]).to eq("/forms/#{form.id}/edit")
        end
      end

      context 'when form is already published' do
        before do
          form.update!(status: 'published')
        end

        it 'identifies already published status' do
          result = service.call

          expect(result).to be_success
          expect(result.result[:ready]).to be false
          
          published_error = result.result[:errors].find { |e| e[:type] == 'already_published' }
          expect(published_error).to be_present
          expect(published_error[:severity]).to eq('info')
        end
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
        expect(result.get_context(:checks_count)).to eq(6)
        expect(result.get_context(:errors_count)).to be_present
      end
    end
  end

  describe 'private methods' do
    describe '#validate_payment_question_configuration' do
      let(:question) { build(:form_question, question_type: 'payment') }

      context 'with valid configuration' do
        before do
          question.question_config = {
            'amount' => '29.99',
            'currency' => 'USD',
            'description' => 'Valid payment configuration'
          }
        end

        it 'returns no errors' do
          errors = service.send(:validate_payment_question_configuration, question)
          expect(errors).to be_empty
        end
      end

      context 'with missing required fields' do
        before do
          question.question_config = {
            'currency' => 'USD'
            # missing amount and description
          }
        end

        it 'returns errors for missing fields' do
          errors = service.send(:validate_payment_question_configuration, question)
          expect(errors).to include('Missing required field: amount')
          expect(errors).to include('Missing required field: description')
        end
      end

      context 'with invalid amount' do
        before do
          question.question_config = {
            'amount' => 'invalid_amount',
            'currency' => 'USD',
            'description' => 'Test'
          }
        end

        it 'returns error for invalid amount' do
          errors = service.send(:validate_payment_question_configuration, question)
          expect(errors).to include('Amount must be a valid number')
        end
      end

      context 'with negative amount' do
        before do
          question.question_config = {
            'amount' => '-10.00',
            'currency' => 'USD',
            'description' => 'Test'
          }
        end

        it 'returns error for negative amount' do
          errors = service.send(:validate_payment_question_configuration, question)
          expect(errors).to include('Amount must be greater than 0')
        end
      end

      context 'with invalid currency' do
        before do
          question.question_config = {
            'amount' => '29.99',
            'currency' => 'INVALID',
            'description' => 'Test'
          }
        end

        it 'returns error for invalid currency' do
          errors = service.send(:validate_payment_question_configuration, question)
          expect(errors).to include('Currency must be a valid 3-letter ISO code (e.g., USD, EUR)')
        end
      end

      context 'with description too long' do
        before do
          question.question_config = {
            'amount' => '29.99',
            'currency' => 'USD',
            'description' => 'a' * 501
          }
        end

        it 'returns error for description too long' do
          errors = service.send(:validate_payment_question_configuration, question)
          expect(errors).to include('Description must be 500 characters or less')
        end
      end
    end

    describe '#check_stripe_webhooks' do
      let(:service) { described_class.new(form: form, user: user) }
      
      context 'when webhook secret is present' do
        before do
          allow(user).to receive(:stripe_webhook_secret).and_return('whsec_test')
        end

        it 'returns configured status' do
          result = service.send(:check_stripe_webhooks)
          expect(result[:configured]).to be true
          expect(result[:issues]).to be_empty
        end
      end

      context 'when webhook secret is missing' do
        before do
          allow(user).to receive(:stripe_webhook_secret).and_return(nil)
        end

        it 'returns not configured status with issues' do
          result = service.send(:check_stripe_webhooks)
          expect(result[:configured]).to be false
          expect(result[:issues]).to include('Webhook secret not configured')
        end
      end
    end

    describe '#generate_recovery_actions' do
      let(:results) do
        {
          errors: [
            { type: 'premium_subscription_required' },
            { type: 'stripe_not_configured' },
            { type: 'payment_question_invalid' }
          ],
          actions: []
        }
      end

      it 'generates appropriate recovery actions for all error types' do
        service.send(:generate_recovery_actions, results)

        action_types = results[:actions].map { |a| a[:type] }
        expect(action_types).to include('upgrade_subscription')
        expect(action_types).to include('configure_stripe')
        expect(action_types).to include('fix_payment_questions')
      end

      it 'removes duplicate actions' do
        # Add duplicate error
        results[:errors] << { type: 'premium_subscription_required' }
        
        service.send(:generate_recovery_actions, results)

        upgrade_actions = results[:actions].select { |a| a[:type] == 'upgrade_subscription' }
        expect(upgrade_actions.length).to eq(1)
      end
    end
  end
end