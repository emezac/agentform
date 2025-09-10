# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Payment Error Handling Integration', type: :request do
  let(:user) { create(:user) }
  let(:form) { create(:form, user: user) }

  before do
    sign_in user
  end

  describe 'form publishing with payment validation errors' do
    let!(:payment_question) do
      create(:form_question, :payment, form: form, configuration: {
        'amount' => 1000,
        'currency' => 'USD'
      })
    end

    context 'when user lacks Stripe configuration' do
      it 'handles error with structured response' do
        patch form_path(form), params: { form: { published: true } }
        
        expect(response).to have_http_status(:redirect)
        expect(flash[:error]).to be_present
        expect(flash[:payment_error]).to include(
          'error_type' => 'stripe_not_configured',
          'required_actions' => array_including('configure_stripe')
        )
      end
    end

    context 'when user lacks Premium subscription' do
      let(:user) { create(:user, :with_stripe) }

      it 'handles premium required error' do
        patch form_path(form), params: { form: { published: true } }
        
        expect(response).to have_http_status(:redirect)
        expect(flash[:payment_error]).to include(
          'error_type' => 'premium_subscription_required',
          'required_actions' => array_including('upgrade_subscription')
        )
      end
    end

    context 'when user has multiple missing requirements' do
      it 'handles multiple requirements error' do
        patch form_path(form), params: { form: { published: true } }
        
        expect(response).to have_http_status(:redirect)
        expect(flash[:payment_error]).to include(
          'error_type' => 'multiple_requirements_missing',
          'required_actions' => array_including('configure_stripe', 'upgrade_subscription')
        )
      end
    end

    context 'with invalid payment question configuration' do
      let(:user) { create(:user, :premium, :with_stripe) }
      let!(:payment_question) do
        create(:form_question, :payment, form: form, configuration: {
          # Missing required configuration
        })
      end

      it 'handles configuration error with details' do
        patch form_path(form), params: { form: { published: true } }
        
        expect(response).to have_http_status(:redirect)
        expect(flash[:payment_error]).to include(
          'error_type' => 'invalid_payment_configuration'
        )
        expect(flash[:payment_error]['user_guidance']['details']).to be_present
      end
    end
  end

  describe 'API error responses' do
    let!(:payment_question) { create(:form_question, :payment, form: form) }

    context 'JSON requests' do
      it 'returns structured JSON error response' do
        patch form_path(form, format: :json), params: { form: { published: true } }
        
        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response).to include(
          'success' => false,
          'status' => 'payment_validation_failed'
        )
        expect(json_response['error']).to include(
          'error_type',
          'message',
          'required_actions',
          'user_guidance'
        )
      end
    end

    context 'Turbo Stream requests' do
      it 'returns Turbo Stream response with error components' do
        patch form_path(form), 
              params: { form: { published: true } },
              headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.content_type).to include('turbo-stream')
        
        # Should include Turbo Stream actions for updating UI
        expect(response.body).to include('turbo-stream')
        expect(response.body).to include('flash-messages')
        expect(response.body).to include('form-publish-button')
      end
    end
  end

  describe 'fallback validation when background jobs fail' do
    let!(:payment_question) { create(:form_question, :payment, form: form) }

    before do
      # Simulate background job failure
      allow(PaymentSetupValidationJob).to receive(:perform_later).and_raise(StandardError, 'Job failed')
    end

    it 'uses fallback validation service' do
      expect(PaymentFallbackValidationService).to receive(:validate_form_payment_setup).with(form).and_call_original
      
      patch form_path(form), params: { form: { published: true } }
      
      expect(response).to have_http_status(:redirect)
      expect(flash[:payment_error]).to be_present
    end

    context 'when fallback validation also fails' do
      before do
        allow(PaymentFallbackValidationService).to receive(:validate_form_payment_setup).and_raise(StandardError, 'Fallback failed')
      end

      it 'provides generic error with support contact' do
        patch form_path(form), params: { form: { published: true } }
        
        expect(response).to have_http_status(:redirect)
        expect(flash[:error]).to include('validation could not be completed')
      end
    end
  end

  describe 'error recovery workflow integration' do
    let(:error) { PaymentValidationErrors.stripe_not_configured }

    context 'GET /payment_setup with error context' do
      before do
        session[:payment_error] = error.to_hash
      end

      it 'generates recovery workflow based on error' do
        get payment_setup_path
        
        expect(response).to have_http_status(:success)
        expect(assigns(:recovery_workflow)).to be_present
        expect(assigns(:recovery_workflow)[:error_type]).to eq('stripe_not_configured')
        expect(assigns(:recovery_workflow)[:steps]).to be_present
      end
    end

    context 'POST /payment_setup/complete_step' do
      let(:step_id) { 'stripe_account_creation' }

      it 'marks step as completed and returns next step' do
        post '/payment_setup/complete_step', params: {
          error_type: 'stripe_not_configured',
          step_id: step_id
        }
        
        expect(response).to have_http_status(:success)
        
        json_response = JSON.parse(response.body)
        expect(json_response['step_completed']).to be true
        expect(json_response['next_step']).to be_present
        expect(json_response['next_step']['id']).to eq('stripe_webhook_configuration')
      end
    end
  end

  describe 'contextual help and educational content' do
    context 'GET /payment_setup/help' do
      it 'provides educational content about payment features' do
        get '/payment_setup/help'
        
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Payment Features')
        expect(response.body).to include('Stripe Integration')
        expect(response.body).to include('Premium Features')
      end
    end

    context 'GET /payment_setup/help/:error_type' do
      it 'provides error-specific help content' do
        get '/payment_setup/help/stripe_not_configured'
        
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Stripe Configuration Help')
        expect(response.body).to include('Go to Stripe Settings')
      end
    end
  end

  describe 'analytics tracking for error handling' do
    let!(:payment_question) { create(:form_question, :payment, form: form) }

    it 'tracks payment validation errors' do
      expect(Rails.logger).to receive(:info).with(match(/Payment validation error tracked/))
      
      patch form_path(form), params: { form: { published: true } }
    end

    it 'tracks error recovery initiation' do
      error = PaymentValidationErrors.stripe_not_configured
      
      expect(Rails.logger).to receive(:info).with(match(/Payment error recovery initiated/))
      
      PaymentErrorRecoveryService.new(error: error, user: user).call
    end
  end

  describe 'error handling across different controllers' do
    let(:template) { create(:form_template, :with_payment_questions) }

    context 'in templates controller' do
      it 'handles payment validation errors when creating form from template' do
        post '/forms', params: {
          form: { template_id: template.id, title: 'Test Form' }
        }
        
        # Should create form but show payment setup guidance
        expect(response).to have_http_status(:redirect)
        created_form = Form.last
        expect(created_form.template_id).to eq(template.id)
        
        # Follow redirect to see payment guidance
        follow_redirect!
        expect(response.body).to include('payment setup')
      end
    end

    context 'in payment_setup controller' do
      it 'provides consistent error handling and guidance' do
        get payment_setup_path
        
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Payment Setup')
      end
    end
  end

  describe 'error message consistency' do
    let!(:payment_question) { create(:form_question, :payment, form: form) }

    it 'provides consistent error messages across different request formats' do
      # HTML request
      patch form_path(form), params: { form: { published: true } }
      html_error_message = flash[:error]
      
      # JSON request
      patch form_path(form, format: :json), params: { form: { published: true } }
      json_response = JSON.parse(response.body)
      json_error_message = json_response['error']['message']
      
      # Messages should be consistent
      expect(html_error_message).to eq(json_error_message)
    end
  end

  describe 'error handling performance' do
    let!(:payment_question) { create(:form_question, :payment, form: form) }

    it 'handles errors efficiently without significant performance impact' do
      start_time = Time.current
      
      patch form_path(form), params: { form: { published: true } }
      
      end_time = Time.current
      response_time = end_time - start_time
      
      # Error handling should complete within reasonable time
      expect(response_time).to be < 1.0 # Less than 1 second
      expect(response).to have_http_status(:redirect)
    end
  end
end