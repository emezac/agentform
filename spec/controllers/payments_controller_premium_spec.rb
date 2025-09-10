require 'rails_helper'

RSpec.describe PaymentsController, type: :controller do
  let(:freemium_user) { create(:user, subscription_tier: 'freemium') }
  let(:premium_user) { create(:user, subscription_tier: 'premium') }
  let(:freemium_form) { create(:form, user: freemium_user) }
  let(:premium_form) { create(:form, user: premium_user) }
  let(:form_response) { create(:form_response, form: freemium_form) }
  let(:premium_form_response) { create(:form_response, form: premium_form) }

  describe 'Premium restrictions' do
    context 'freemium user form' do
      it 'prevents payment creation' do
        post :create, params: {
          share_token: freemium_form.share_token,
          form_response_id: form_response.id,
          payment: {
            amount: 100,
            currency: 'USD',
            payment_method: 'credit_card'
          }
        }, format: :json

        expect(response).to have_http_status(:forbidden)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['error']).to include('Payment processing not available')
      end

      it 'prevents payment config access' do
        get :config, params: {
          share_token: freemium_form.share_token
        }, format: :json

        expect(response).to have_http_status(:forbidden)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['error']).to include('Payment processing not available')
      end
    end

    context 'premium user form without stripe configured' do
      it 'prevents payment creation without stripe setup' do
        post :create, params: {
          share_token: premium_form.share_token,
          form_response_id: premium_form_response.id,
          payment: {
            amount: 100,
            currency: 'USD',
            payment_method: 'credit_card'
          }
        }, format: :json

        expect(response).to have_http_status(:forbidden)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['error']).to include('Payment processing not available')
      end
    end

    context 'premium user with stripe configured' do
      before do
        premium_user.update!(
          stripe_enabled: true,
          stripe_publishable_key: 'pk_test_123',
          stripe_secret_key: 'sk_test_123'
        )
      end

      it 'allows payment config access' do
        get :config, params: {
          share_token: premium_form.share_token
        }, format: :json

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(json_response['publishable_key']).to eq('pk_test_123')
      end

      it 'allows payment creation (would call Stripe service)' do
        # Mock the Stripe service to avoid actual API calls
        allow(StripePaymentService).to receive(:call).and_return(
          double(
            success?: true,
            data: {
              client_secret: 'pi_test_123_secret',
              payment_intent: double(id: 'pi_test_123'),
              transaction: double(id: 'txn_123')
            }
          )
        )

        post :create, params: {
          share_token: premium_form.share_token,
          form_response_id: premium_form_response.id,
          payment: {
            amount: 100,
            currency: 'USD',
            payment_method: 'credit_card'
          }
        }, format: :json

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(json_response['payment_intent_id']).to eq('pi_test_123')
      end
    end
  end
end