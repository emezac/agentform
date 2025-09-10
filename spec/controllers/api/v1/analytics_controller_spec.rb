require 'rails_helper'

RSpec.describe Api::V1::AnalyticsController, type: :controller do
  let(:user) { create(:user, subscription_tier: 'basic') }

  before do
    sign_in user
  end

  describe 'POST #payment_setup' do
    let(:valid_event_data) do
      {
        event: {
          has_payment_questions: true,
          stripe_configured: false,
          is_premium: false,
          required_features: ['stripe_payments', 'premium_subscription'],
          event_type: 'setup_initiated',
          timestamp: Time.current.iso8601,
          action: 'stripe_configuration'
        }
      }
    end

    it 'successfully logs payment setup event' do
      expect(Rails.logger).to receive(:info).with(/Payment Setup Event:/)
      
      post :payment_setup, params: valid_event_data

      expect(response).to have_http_status(:success)
      
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
    end

    it 'returns bad request for missing event parameter' do
      post :payment_setup, params: {}

      expect(response).to have_http_status(:bad_request)
      
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be false
      expect(json_response['error']).to include('Missing required parameter: event')
    end

    context 'when user is not authenticated' do
      before do
        sign_out user
      end

      it 'returns unauthorized status' do
        post :payment_setup, params: valid_event_data
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST #payment_errors' do
    let(:valid_error_data) do
      {
        event: {
          error_type: 'stripe_not_configured',
          event_type: 'error_displayed',
          timestamp: Time.current.iso8601,
          required_actions: ['configure_stripe']
        }
      }
    end

    it 'successfully logs payment error event' do
      expect(Rails.logger).to receive(:info).with(/Payment Error Event:/)
      
      post :payment_errors, params: valid_error_data

      expect(response).to have_http_status(:success)
      
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
    end

    it 'returns bad request for missing event parameter' do
      post :payment_errors, params: {}

      expect(response).to have_http_status(:bad_request)
      
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be false
      expect(json_response['error']).to include('Missing required parameter: event')
    end

    context 'when user is not authenticated' do
      before do
        sign_out user
      end

      it 'returns unauthorized status' do
        post :payment_errors, params: valid_error_data
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end