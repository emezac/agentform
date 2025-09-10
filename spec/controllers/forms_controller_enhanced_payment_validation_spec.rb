# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FormsController, type: :controller do
  describe 'Enhanced Payment Validation Integration' do
    let(:user) { create(:user) }
    let(:payment_form) { create(:form, :with_payment_questions, user: user) }

    before do
      allow(controller).to receive(:authenticate_user!).and_return(true)
      allow(controller).to receive(:current_user).and_return(user)
    end

    describe 'POST #publish with enhanced payment validation' do
      context 'when form has payment questions and user setup is incomplete' do
        let(:validation_service) { instance_double(FormPublishValidationService) }
        let(:validation_result) { double('ServiceResult') }

        before do
          allow(user).to receive(:stripe_configured?).and_return(false)
          allow(user).to receive(:premium?).and_return(true)
          
          allow(FormPublishValidationService).to receive(:new).with(form: payment_form).and_return(validation_service)
          allow(validation_service).to receive(:call).and_return(validation_result)
          allow(validation_service).to receive(:failure?).and_return(false)
          allow(validation_result).to receive(:result).and_return({
            can_publish: false,
            validation_errors: [{
              type: 'stripe_not_configured',
              title: 'Stripe Configuration Required',
              description: 'Configure Stripe to accept payments'
            }],
            required_actions: [{
              type: 'stripe_setup',
              action_url: '/stripe_settings',
              action_text: 'Configure Stripe'
            }]
          })
        end

        it 'calls the FormPublishValidationService' do
          expect {
            post :publish, params: { id: payment_form.id }
          }.to raise_error(PaymentValidationError)
          
          expect(FormPublishValidationService).to have_received(:new).with(form: payment_form)
          expect(validation_service).to have_received(:call)
        end

        it 'handles validation failures with PaymentValidationError' do
          expect {
            post :publish, params: { id: payment_form.id }
          }.to raise_error(PaymentValidationError) do |error|
            expect(error.error_type).to eq('stripe_not_configured')
          end
        end

        it 'prevents form from being published' do
          expect {
            post :publish, params: { id: payment_form.id }
          }.to raise_error(PaymentValidationError)
          
          payment_form.reload
          expect(payment_form.status).not_to eq('published')
        end
      end

      context 'when validation service raises an exception' do
        let(:validation_service) { instance_double(FormPublishValidationService) }

        before do
          allow(FormPublishValidationService).to receive(:new).and_return(validation_service)
          allow(validation_service).to receive(:call).and_raise(StandardError.new('Service error'))
          allow(user).to receive(:stripe_configured?).and_return(false)
          allow(user).to receive(:premium?).and_return(false)
        end

        it 'performs fallback validation' do
          expect(controller).to receive(:perform_fallback_payment_validation).and_call_original
          
          expect {
            post :publish, params: { id: payment_form.id }
          }.to raise_error(PaymentValidationError)
        end

        it 'logs the service error' do
          expect(Rails.logger).to receive(:error).with(/Payment validation service error/)
          
          expect {
            post :publish, params: { id: payment_form.id }
          }.to raise_error(PaymentValidationError)
        end
      end

      context 'when form has no payment questions' do
        let(:regular_form) { create(:form, user: user) }

        before do
          create(:form_question, form: regular_form, question_type: 'text')
        end

        it 'skips payment validation and publishes successfully' do
          expect(FormPublishValidationService).not_to receive(:new)
          
          post :publish, params: { id: regular_form.id }
          
          regular_form.reload
          expect(regular_form.status).to eq('published')
          expect(response).to redirect_to(regular_form)
        end
      end
    end

    describe 'helper methods' do
      describe '#estimate_setup_time' do
        it 'provides appropriate time estimates' do
          stripe_error = PaymentValidationErrors.stripe_not_configured
          expect(controller.send(:estimate_setup_time, stripe_error)).to eq('5-10 minutes')

          premium_error = PaymentValidationErrors.premium_required
          expect(controller.send(:estimate_setup_time, premium_error)).to eq('2-3 minutes')
        end
      end

      describe '#payment_help_resources' do
        it 'provides help resources' do
          resources = controller.send(:payment_help_resources)
          
          expect(resources).to be_an(Array)
          expect(resources.length).to eq(3)
          expect(resources.first).to include(:title, :url, :type)
        end
      end
    end

    describe 'fallback validation' do
      before do
        controller.instance_variable_set(:@form, payment_form)
        allow(user).to receive(:stripe_configured?).and_return(false)
        allow(user).to receive(:premium?).and_return(false)
      end

      it 'identifies missing requirements' do
        expect {
          controller.send(:perform_fallback_payment_validation)
        }.to raise_error(PaymentValidationError) do |error|
          expect(error.error_type).to eq('multiple_requirements_missing')
          expect(error.required_actions).to include('complete_stripe_configuration')
          expect(error.required_actions).to include('complete_premium_subscription')
        end
      end

      it 'passes when all requirements are met' do
        allow(user).to receive(:stripe_configured?).and_return(true)
        allow(user).to receive(:premium?).and_return(true)
        
        # Add proper payment question configuration
        payment_question = payment_form.form_questions.where(question_type: 'payment').first
        payment_question.update!(question_config: { amount: 100, currency: 'USD' })

        expect {
          controller.send(:perform_fallback_payment_validation)
        }.not_to raise_error
      end
    end
  end
end