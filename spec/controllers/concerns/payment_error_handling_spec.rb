# frozen_string_literal: true

require 'rails_helper'

# Test controller to include the PaymentErrorHandling concern
class TestPaymentErrorController < ApplicationController
  include PaymentErrorHandling

  def trigger_stripe_error
    raise PaymentValidationErrors.stripe_not_configured
  end

  def trigger_premium_error
    raise PaymentValidationErrors.premium_required
  end

  def trigger_multiple_requirements_error
    raise PaymentValidationErrors.multiple_requirements(['stripe_config', 'premium_subscription'])
  end

  def trigger_custom_error
    raise PaymentValidationErrors.custom_error(
      error_type: 'test_error',
      message: 'Test error message',
      required_actions: ['test_action'],
      action_url: '/test_url'
    )
  end
end

RSpec.describe PaymentErrorHandling, type: :controller do
  controller(TestPaymentErrorController) do
    # Use the test controller defined above
  end

  let(:user) { create(:user) }

  before do
    sign_in user
    
    # Add routes for test actions
    routes.draw do
      get 'trigger_stripe_error', to: 'test_payment_error#trigger_stripe_error'
      get 'trigger_premium_error', to: 'test_payment_error#trigger_premium_error'
      get 'trigger_multiple_requirements_error', to: 'test_payment_error#trigger_multiple_requirements_error'
      get 'trigger_custom_error', to: 'test_payment_error#trigger_custom_error'
    end
  end

  describe 'PaymentValidationError handling' do
    context 'HTML requests' do
      it 'handles stripe_not_configured error' do
        get :trigger_stripe_error

        expect(response).to redirect_to('/stripe_settings')
        expect(flash[:error]).to eq('Stripe configuration required for payment questions')
        expect(flash[:payment_error]).to be_present
        expect(flash[:payment_error][:error_type]).to eq('stripe_not_configured')
      end

      it 'handles premium_required error' do
        get :trigger_premium_error

        expect(response).to redirect_to('/subscription_management')
        expect(flash[:error]).to eq('Premium subscription required for payment features')
        expect(flash[:payment_error]).to be_present
        expect(flash[:payment_error][:error_type]).to eq('premium_subscription_required')
      end

      it 'handles multiple_requirements error' do
        get :trigger_multiple_requirements_error

        expect(response).to redirect_to('/payment_setup_guide')
        expect(flash[:error]).to eq('Multiple setup steps required for payment features')
        expect(flash[:payment_error]).to be_present
        expect(flash[:payment_error][:error_type]).to eq('multiple_requirements_missing')
      end

      it 'redirects to action URL when available' do
        get :trigger_custom_error

        expect(response).to redirect_to('/test_url')
        expect(flash[:error]).to eq('Test error message')
      end
    end

    context 'JSON requests' do
      it 'returns JSON error response for stripe_not_configured' do
        get :trigger_stripe_error, format: :json

        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['status']).to eq('payment_validation_failed')
        expect(json_response['error']['error_type']).to eq('stripe_not_configured')
        expect(json_response['error']['message']).to eq('Stripe configuration required for payment questions')
        expect(json_response['error']['required_actions']).to eq(['configure_stripe'])
      end

      it 'returns JSON error response for premium_required' do
        get :trigger_premium_error, format: :json

        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['error']['error_type']).to eq('premium_subscription_required')
        expect(json_response['error']['required_actions']).to eq(['upgrade_subscription'])
      end

      it 'returns JSON error response for multiple_requirements' do
        get :trigger_multiple_requirements_error, format: :json

        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['error']['error_type']).to eq('multiple_requirements_missing')
        expect(json_response['error']['required_actions']).to eq(['complete_stripe_config', 'complete_premium_subscription'])
      end

      it 'includes user_guidance in JSON response' do
        get :trigger_custom_error, format: :json

        json_response = JSON.parse(response.body)
        expect(json_response['error']['user_guidance']['action_url']).to eq('/test_url')
      end
    end

    context 'Turbo Stream requests' do
      it 'renders turbo stream response for payment errors' do
        get :trigger_stripe_error, format: :turbo_stream

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('text/vnd.turbo-stream.html')
        expect(response.body).to include('turbo-stream')
        expect(response.body).to include('flash-messages')
        expect(response.body).to include('form-publish-button')
      end

      it 'includes error information in turbo stream response' do
        get :trigger_premium_error, format: :turbo_stream

        expect(response.body).to include('turbo-stream')
        expect(response.body).to include('flash-messages')
        expect(response.body).to include('form-publish-button')
      end
    end
  end

  describe 'helper methods' do
    describe '#payment_related_request?' do
      it 'returns true for payment controller' do
        allow(controller).to receive(:params).and_return({ controller: 'payments' })
        
        expect(controller.send(:payment_related_request?)).to be true
      end

      it 'returns true for payment action' do
        allow(controller).to receive(:params).and_return({ action: 'payment_setup' })
        
        expect(controller.send(:payment_related_request?)).to be true
      end

      it 'returns true for payment path' do
        allow(controller).to receive(:request).and_return(double(path: '/forms/payment'))
        
        expect(controller.send(:payment_related_request?)).to be true
      end

      it 'returns false for non-payment requests' do
        allow(controller).to receive(:params).and_return({ controller: 'forms', action: 'index' })
        allow(controller).to receive(:request).and_return(double(path: '/forms'))
        
        expect(controller.send(:payment_related_request?)).to be false
      end
    end

    describe '#add_payment_error_context' do
      it 'adds payment error context to flash' do
        error = PaymentValidationErrors.stripe_not_configured
        
        controller.send(:add_payment_error_context, error)
        
        expect(flash[:payment_error_context]).to be_present
        expect(flash[:payment_error_context][:error_type]).to eq('stripe_not_configured')
        expect(flash[:payment_error_context][:required_actions]).to eq(['configure_stripe'])
        expect(flash[:payment_error_context][:action_url]).to eq('/stripe_settings')
        expect(flash[:payment_error_context][:action_text]).to eq('Configure Stripe')
      end
    end
  end

  describe 'error logging' do
    it 'logs payment validation errors' do
      expect(Rails.logger).to receive(:warn).with(/Payment validation error/)
      expect(Rails.logger).to receive(:warn).with(/Error details/)
      
      get :trigger_stripe_error
    end

    it 'logs error details in structured format' do
      expect(Rails.logger).to receive(:warn).with(/Payment validation error/)
      expect(Rails.logger).to receive(:warn).with(/Error details/)
      
      get :trigger_stripe_error
    end
  end

  describe 'integration with existing error handling' do
    it 'does not interfere with other error types' do
      controller_class = Class.new(ApplicationController) do
        def test_action
          raise StandardError, 'Regular error'
        end
      end

      expect {
        controller_instance = controller_class.new
        controller_instance.send(:test_action)
      }.to raise_error(StandardError, 'Regular error')
    end

    it 'maintains existing rescue_from handlers' do
      # Verify that ApplicationController's existing rescue handlers still work
      expect(controller.class.rescue_handlers).to be_present
      
      # Check that PaymentValidationError handler is added by checking if the concern is included
      expect(controller.class.included_modules).to include(PaymentErrorHandling)
    end
  end
end