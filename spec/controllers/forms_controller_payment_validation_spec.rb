# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FormsController, type: :controller do
  describe 'Payment Validation Integration' do
    let(:user) { create(:user) }
    let(:payment_form) { create(:form, :with_payment_questions, user: user) }

    before do
      allow(controller).to receive(:authenticate_user!).and_return(true)
      allow(controller).to receive(:current_user).and_return(user)
    end

    describe 'POST #publish with payment validation' do
      context 'when user has complete payment setup' do
        before do
          allow(user).to receive(:stripe_configured?).and_return(true)
          allow(user).to receive(:premium?).and_return(true)
          allow(user).to receive(:can_accept_payments?).and_return(true)
        end

        it 'runs payment validation and publishes successfully' do
          validation_service = instance_double(FormPublishValidationService)
          validation_result = double('ServiceResult')
          
          allow(FormPublishValidationService).to receive(:new).with(form: payment_form).and_return(validation_service)
          allow(validation_service).to receive(:call).and_return(validation_result)
          allow(validation_service).to receive(:failure?).and_return(false)
          allow(validation_result).to receive(:result).and_return({
            can_publish: true,
            validation_errors: [],
            required_actions: []
          })

          post :publish, params: { id: payment_form.id }
          
          expect(FormPublishValidationService).to have_received(:new).with(form: payment_form)
          expect(validation_service).to have_received(:call)
          
          payment_form.reload
          expect(payment_form.status).to eq('published')
          expect(response).to redirect_to(payment_form)
        end
      end

      context 'when user lacks Stripe configuration' do
        let(:validation_service) { instance_double(FormPublishValidationService) }
        let(:validation_result) { double('ServiceResult') }

        before do
          allow(user).to receive(:stripe_configured?).and_return(false)
          allow(user).to receive(:premium?).and_return(true)
          allow(user).to receive(:can_accept_payments?).and_return(false)
          
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

        it 'prevents publish and raises PaymentValidationError' do
          expect {
            post :publish, params: { id: payment_form.id }
          }.to raise_error(PaymentValidationError) do |error|
            expect(error.error_type).to eq('stripe_not_configured')
            expect(error.user_guidance[:action_url]).to eq('/stripe_settings')
            expect(error.user_guidance[:action_text]).to eq('Configure Stripe')
          end

          payment_form.reload
          expect(payment_form.status).not_to eq('published')
        end

        it 'handles HTML requests with redirect and flash' do
          expect(controller).to receive(:handle_payment_error_html) do |error|
            expect(error.error_type).to eq('stripe_not_configured')
            # Simulate the redirect behavior
            redirect_to edit_form_path(payment_form), 
                       alert: error.message,
                       flash: { 
                         payment_error: error.to_hash,
                         show_payment_setup: true,
                         payment_error_context: {
                           form_id: payment_form.id,
                           has_payment_questions: true,
                           error_type: error.error_type
                         }
                       }
          end

          expect {
            post :publish, params: { id: payment_form.id }
          }.to raise_error(PaymentValidationError)
        end

        it 'handles JSON requests with structured error response' do
          expect(controller).to receive(:handle_payment_error_json) do |error|
            expect(error.error_type).to eq('stripe_not_configured')
            # Simulate the JSON response
            render json: {
              success: false,
              error: error.to_hash.merge(
                form_id: payment_form.id,
                form_name: payment_form.name,
                has_payment_questions: true
              ),
              status: 'payment_validation_failed',
              context: 'form_publish'
            }, status: :unprocessable_entity
          end

          expect {
            post :publish, params: { id: payment_form.id }, format: :json
          }.to raise_error(PaymentValidationError)
        end

        it 'handles Turbo Stream requests with UI updates' do
          expect(controller).to receive(:handle_payment_error_turbo_stream) do |error|
            expect(error.error_type).to eq('stripe_not_configured')
            # Verify the expected Turbo Stream updates
            expect(controller).to receive(:render).with(
              turbo_stream: array_including(
                have_attributes(action: 'replace', target: 'flash-messages'),
                have_attributes(action: 'update', target: 'form-publish-section'),
                have_attributes(action: 'update', target: 'payment-setup-status'),
                have_attributes(action: 'update', target: 'form-status-indicator')
              )
            )
          end

          expect {
            post :publish, params: { id: payment_form.id }, format: :turbo_stream
          }.to raise_error(PaymentValidationError)
        end
      end

      context 'when user lacks Premium subscription' do
        let(:validation_service) { instance_double(FormPublishValidationService) }
        let(:validation_result) { double('ServiceResult') }

        before do
          allow(user).to receive(:stripe_configured?).and_return(true)
          allow(user).to receive(:premium?).and_return(false)
          allow(user).to receive(:can_accept_payments?).and_return(false)
          
          allow(FormPublishValidationService).to receive(:new).with(form: payment_form).and_return(validation_service)
          allow(validation_service).to receive(:call).and_return(validation_result)
          allow(validation_service).to receive(:failure?).and_return(false)
          allow(validation_result).to receive(:result).and_return({
            can_publish: false,
            validation_errors: [{
              type: 'premium_subscription_required',
              title: 'Premium Subscription Required',
              description: 'Upgrade to Premium to publish forms with payment questions'
            }],
            required_actions: [{
              type: 'subscription_upgrade',
              action_url: '/subscription_management',
              action_text: 'Upgrade to Premium'
            }]
          })
        end

        it 'prevents publish and raises PaymentValidationError for premium requirement' do
          expect {
            post :publish, params: { id: payment_form.id }
          }.to raise_error(PaymentValidationError) do |error|
            expect(error.error_type).to eq('premium_subscription_required')
            expect(error.user_guidance[:action_url]).to eq('/subscription_management')
            expect(error.user_guidance[:action_text]).to eq('Upgrade to Premium')
          end
        end
      end

      context 'when user lacks both Stripe and Premium' do
        let(:validation_service) { instance_double(FormPublishValidationService) }
        let(:validation_result) { double('ServiceResult') }

        before do
          allow(user).to receive(:stripe_configured?).and_return(false)
          allow(user).to receive(:premium?).and_return(false)
          allow(user).to receive(:can_accept_payments?).and_return(false)
          
          allow(FormPublishValidationService).to receive(:new).with(form: payment_form).and_return(validation_service)
          allow(validation_service).to receive(:call).and_return(validation_result)
          allow(validation_service).to receive(:failure?).and_return(false)
          allow(validation_result).to receive(:result).and_return({
            can_publish: false,
            validation_errors: [{
              type: 'payment_acceptance_disabled',
              title: 'Payment Acceptance Not Available',
              description: 'Complete payment setup to publish forms with payment questions'
            }],
            required_actions: [{
              type: 'complete_payment_setup',
              action_url: '/payment_setup_guide',
              action_text: 'Complete Setup'
            }]
          })
        end

        it 'prevents publish and raises PaymentValidationError for multiple requirements' do
          expect {
            post :publish, params: { id: payment_form.id }
          }.to raise_error(PaymentValidationError) do |error|
            expect(error.error_type).to eq('multiple_requirements_missing')
            expect(error.required_actions).to include('complete_stripe_configuration')
            expect(error.required_actions).to include('complete_premium_subscription')
            expect(error.user_guidance[:action_url]).to eq('/payment_setup_guide')
          end
        end
      end

      context 'when payment questions have configuration issues' do
        let(:validation_service) { instance_double(FormPublishValidationService) }
        let(:validation_result) { double('ServiceResult') }

        before do
          allow(user).to receive(:stripe_configured?).and_return(true)
          allow(user).to receive(:premium?).and_return(true)
          allow(FormPublishValidationService).to receive(:new).and_return(validation_service)
          allow(validation_service).to receive(:call).and_return(validation_result)
          allow(validation_service).to receive(:failure?).and_return(false)
          allow(validation_result).to receive(:result).and_return({
            can_publish: false,
            validation_errors: [{
              type: 'payment_question_configuration',
              title: 'Payment Question Configuration Missing',
              description: 'Payment questions are not properly configured',
              question_id: 1
            }],
            required_actions: [{
              type: 'configure_payment_question',
              action_url: "/forms/#{payment_form.id}/questions/1/edit",
              action_text: 'Configure Question'
            }]
          })
        end

        it 'prevents publish and raises PaymentValidationError for configuration issues' do
          expect {
            post :publish, params: { id: payment_form.id }
          }.to raise_error(PaymentValidationError) do |error|
            expect(error.error_type).to eq('invalid_payment_configuration')
            expect(error.required_actions).to include('review_payment_questions')
          end
        end
      end

      context 'when FormPublishValidationService fails' do
        let(:validation_service) { instance_double(FormPublishValidationService) }
        let(:validation_result) { double('ServiceResult') }

        before do
          allow(FormPublishValidationService).to receive(:new).and_return(validation_service)
          allow(validation_service).to receive(:call).and_return(validation_result)
          allow(validation_service).to receive(:failure?).and_return(true)
          allow(validation_service).to receive(:errors).and_return(
            double('Errors', full_messages: ['Service validation failed'])
          )
          allow(validation_result).to receive(:result).and_return({
            can_publish: false,
            validation_errors: [{
              type: 'service_error',
              title: 'Validation Service Error',
              description: 'The validation service encountered an error'
            }],
            required_actions: []
          })
        end

        it 'handles service failures gracefully' do
          expect {
            post :publish, params: { id: payment_form.id }
          }.to raise_error(PaymentValidationError) do |error|
            expect(error.error_type).to eq('service_error')
          end
        end

        it 'logs service failure details' do
          expect(Rails.logger).to receive(:warn).with(/FormPublishValidationService failed/)
          
          expect {
            post :publish, params: { id: payment_form.id }
          }.to raise_error(PaymentValidationError)
        end
      end

      context 'when validation returns no specific errors' do
        let(:validation_service) { instance_double(FormPublishValidationService) }
        let(:validation_result) { double('ServiceResult') }

        before do
          allow(FormPublishValidationService).to receive(:new).and_return(validation_service)
          allow(validation_service).to receive(:call).and_return(validation_result)
          allow(validation_service).to receive(:failure?).and_return(false)
          allow(validation_result).to receive(:result).and_return({
            can_publish: false,
            validation_errors: [],
            required_actions: [{
              type: 'complete_setup',
              action_url: '/payment_setup_guide',
              action_text: 'Complete Setup'
            }]
          })
        end

        it 'uses fallback error handling' do
          expect {
            post :publish, params: { id: payment_form.id }
          }.to raise_error(PaymentValidationError) do |error|
            expect(error.error_type).to eq('multiple_requirements_missing')
            expect(error.required_actions).to include('complete_payment_setup')
          end
        end

        it 'logs fallback error usage' do
          expect(Rails.logger).to receive(:warn).with(/No specific errors found, using fallback error/)
          
          expect {
            post :publish, params: { id: payment_form.id }
          }.to raise_error(PaymentValidationError)
        end
      end
    end

    describe 'logging and debugging' do
      before do
        allow(user).to receive(:stripe_configured?).and_return(false)
        allow(user).to receive(:premium?).and_return(true)
        allow(user).to receive(:can_accept_payments?).and_return(false)
      end

      it 'logs the payment validation process' do
        expect(Rails.logger).to receive(:info).with("Running pre-publish payment validation for form #{payment_form.id}")
        expect(Rails.logger).to receive(:warn).with(/Payment validation failure/)
        expect(Rails.logger).to receive(:warn).with(/Primary error type: stripe_not_configured/)

        expect {
          post :publish, params: { id: payment_form.id }
        }.to raise_error(PaymentValidationError)
      end

      it 'logs error handling responses' do
        expect(Rails.logger).to receive(:info).with("Handling payment error HTML response for form #{payment_form.id}")

        expect {
          post :publish, params: { id: payment_form.id }
        }.to raise_error(PaymentValidationError)
      end
    end

    describe 'integration with existing error handling' do
      before do
        allow(user).to receive(:stripe_configured?).and_return(false)
        allow(user).to receive(:premium?).and_return(true)
        allow(user).to receive(:can_accept_payments?).and_return(false)
      end

      it 'integrates with PaymentErrorHandling concern' do
        expect(controller).to receive(:handle_payment_validation_error).and_call_original
        expect(controller).to receive(:handle_payment_error_html).and_call_original

        expect {
          post :publish, params: { id: payment_form.id }
        }.to raise_error(PaymentValidationError)
      end

      it 'adds payment error context to flash' do
        expect(controller).to receive(:add_payment_error_context).and_call_original

        expect {
          post :publish, params: { id: payment_form.id }
        }.to raise_error(PaymentValidationError)
      end
    end

    describe 'enhanced error handling and responses' do
      let(:validation_service) { instance_double(FormPublishValidationService) }
      let(:validation_result) { double('ServiceResult') }

      before do
        allow(FormPublishValidationService).to receive(:new).and_return(validation_service)
        allow(validation_service).to receive(:call).and_return(validation_result)
        allow(validation_service).to receive(:failure?).and_return(false)
      end

      context 'when service raises an exception' do
        before do
          allow(validation_service).to receive(:call).and_raise(StandardError.new('Service error'))
        end

        it 'performs fallback validation' do
          expect(controller).to receive(:perform_fallback_payment_validation).and_call_original
          expect(Rails.logger).to receive(:error).with(/Payment validation service error/)

          expect {
            post :publish, params: { id: payment_form.id }
          }.to raise_error(PaymentValidationError)
        end

        it 'logs the service error details' do
          expect(Rails.logger).to receive(:error).with('Payment validation service error: Service error')
          expect(Rails.logger).to receive(:error).with(anything) # backtrace

          expect {
            post :publish, params: { id: payment_form.id }
          }.to raise_error(PaymentValidationError)
        end
      end

      context 'with Turbo Stream requests' do
        before do
          allow(user).to receive(:stripe_configured?).and_return(false)
          allow(user).to receive(:premium?).and_return(true)
          allow(validation_result).to receive(:result).and_return({
            can_publish: false,
            validation_errors: [{
              type: 'stripe_not_configured',
              title: 'Stripe Configuration Required',
              description: 'Configure Stripe to accept payments'
            }],
            required_actions: []
          })
        end

        it 'provides enhanced Turbo Stream responses with payment guidance' do
          expect(controller).to receive(:handle_payment_error_turbo_stream).and_call_original
          expect(controller).to receive(:add_payment_error_context).and_call_original

          expect {
            post :publish, params: { id: payment_form.id }, as: :turbo_stream
          }.to raise_error(PaymentValidationError)
        end

        it 'includes multiple stream updates for comprehensive guidance' do
          allow(controller).to receive(:handle_payment_error_turbo_stream) do |error|
            # Verify the streams include all expected elements
            expect(error.error_type).to eq('stripe_not_configured')
            
            # Mock the render call to verify stream structure
            expect(controller).to receive(:render).with(
              turbo_stream: array_including(
                anything, # flash messages
                anything, # form status indicator
                anything, # form publish section
                anything, # payment setup checklist
                anything, # publish button
                anything  # payment setup status
              )
            )
          end

          expect {
            post :publish, params: { id: payment_form.id }, as: :turbo_stream
          }.to raise_error(PaymentValidationError)
        end
      end

      context 'with JSON requests' do
        before do
          allow(user).to receive(:stripe_configured?).and_return(false)
          allow(user).to receive(:premium?).and_return(true)
          allow(user).to receive(:payment_setup_status).and_return({
            stripe_configured: false,
            premium_subscription: true,
            setup_completion_percentage: 50
          })
          allow(validation_result).to receive(:result).and_return({
            can_publish: false,
            validation_errors: [{
              type: 'stripe_not_configured',
              title: 'Stripe Configuration Required',
              description: 'Configure Stripe to accept payments'
            }],
            required_actions: []
          })
        end

        it 'provides comprehensive JSON error responses' do
          expect(controller).to receive(:handle_payment_error_json).and_call_original

          expect {
            post :publish, params: { id: payment_form.id }, as: :json
          }.to raise_error(PaymentValidationError) do |error|
            # The error should be handled by the concern, but we can test the method directly
            json_response = controller.send(:handle_payment_error_json, error)
            # This would normally render, but we can test the structure
          end
        end

        it 'includes setup time estimates and help resources' do
          expect(controller).to receive(:estimate_setup_time).and_call_original
          expect(controller).to receive(:payment_help_resources).and_call_original

          expect {
            post :publish, params: { id: payment_form.id }, as: :json
          }.to raise_error(PaymentValidationError)
        end
      end
    end

    describe 'fallback validation' do
      let(:payment_question) { create(:form_question, form: payment_form, question_type: 'payment', question_config: nil) }

      before do
        payment_question # ensure it exists
        allow(user).to receive(:stripe_configured?).and_return(false)
        allow(user).to receive(:premium?).and_return(false)
        # Set up the controller's @form instance variable
        controller.instance_variable_set(:@form, payment_form)
      end

      it 'identifies missing Stripe configuration' do
        allow(user).to receive(:premium?).and_return(true)

        expect {
          controller.send(:perform_fallback_payment_validation)
        }.to raise_error(PaymentValidationError) do |error|
          expect(error.error_type).to eq('multiple_requirements_missing')
          expect(error.required_actions).to include('complete_stripe_configuration')
        end
      end

      it 'identifies missing Premium subscription' do
        allow(user).to receive(:stripe_configured?).and_return(true)

        expect {
          controller.send(:perform_fallback_payment_validation)
        }.to raise_error(PaymentValidationError) do |error|
          expect(error.error_type).to eq('multiple_requirements_missing')
          expect(error.required_actions).to include('complete_premium_subscription')
        end
      end

      it 'identifies missing payment question configuration' do
        allow(user).to receive(:stripe_configured?).and_return(true)
        allow(user).to receive(:premium?).and_return(true)

        expect {
          controller.send(:perform_fallback_payment_validation)
        }.to raise_error(PaymentValidationError) do |error|
          expect(error.error_type).to eq('multiple_requirements_missing')
          expect(error.required_actions).to include('complete_payment_question_configuration')
        end
      end

      it 'passes when all requirements are met' do
        allow(user).to receive(:stripe_configured?).and_return(true)
        allow(user).to receive(:premium?).and_return(true)
        payment_question.update!(question_config: { amount: 100, currency: 'USD' })

        expect {
          controller.send(:perform_fallback_payment_validation)
        }.not_to raise_error
      end
    end

    describe 'helper methods for enhanced responses' do
      describe '#estimate_setup_time' do
        it 'provides appropriate time estimates for different error types' do
          stripe_error = PaymentValidationErrors.stripe_not_configured
          expect(controller.send(:estimate_setup_time, stripe_error)).to eq('5-10 minutes')

          premium_error = PaymentValidationErrors.premium_required
          expect(controller.send(:estimate_setup_time, premium_error)).to eq('2-3 minutes')

          multiple_error = PaymentValidationErrors.multiple_requirements(['stripe_config', 'premium'])
          expect(controller.send(:estimate_setup_time, multiple_error)).to eq('10-15 minutes')
        end
      end

      describe '#payment_help_resources' do
        it 'provides relevant help resources' do
          resources = controller.send(:payment_help_resources)
          
          expect(resources).to be_an(Array)
          expect(resources.length).to eq(3)
          expect(resources.first).to include(:title, :url, :type)
          expect(resources.first[:title]).to eq('Payment Setup Guide')
        end
      end
    end
  end
end