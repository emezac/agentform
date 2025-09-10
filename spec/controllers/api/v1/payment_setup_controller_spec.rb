require 'rails_helper'

RSpec.describe Api::V1::PaymentSetupController, type: :controller do
  let(:user) { create(:user, subscription_tier: 'basic') }
  let(:premium_user) { create(:user, subscription_tier: 'premium', stripe_enabled: true, stripe_publishable_key: 'pk_test_123', stripe_secret_key: 'sk_test_123') }

  before do
    sign_in user
  end

  describe 'GET #status' do
    context 'when user has no setup' do
      it 'returns correct status for basic user without Stripe' do
        get :status

        expect(response).to have_http_status(:success)
        
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(json_response['setup_status']).to include(
          'stripe_configured' => false,
          'premium_subscription' => false,
          'can_accept_payments' => false,
          'setup_completion_percentage' => 0
        )
      end
    end

    context 'when user has partial setup' do
      before do
        user.update!(stripe_enabled: true, stripe_publishable_key: 'pk_test_123', stripe_secret_key: 'sk_test_123')
      end

      it 'returns correct status for user with Stripe but no premium' do
        get :status

        expect(response).to have_http_status(:success)
        
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(json_response['setup_status']).to include(
          'stripe_configured' => true,
          'premium_subscription' => false,
          'can_accept_payments' => false,
          'setup_completion_percentage' => 50
        )
      end
    end

    context 'when user has complete setup' do
      before do
        sign_out user
        sign_in premium_user
      end

      it 'returns correct status for premium user with Stripe' do
        get :status

        expect(response).to have_http_status(:success)
        
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(json_response['setup_status']).to include(
          'stripe_configured' => true,
          'premium_subscription' => true,
          'can_accept_payments' => true,
          'setup_completion_percentage' => 100
        )
      end
    end

    context 'when user is not authenticated' do
      before do
        sign_out user
      end

      it 'returns unauthorized status' do
        get :status
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end