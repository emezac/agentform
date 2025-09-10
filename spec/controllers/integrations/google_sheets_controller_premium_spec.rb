require 'rails_helper'

RSpec.describe Integrations::GoogleSheetsController, type: :controller do
  let(:form) { create(:form, user: user) }

  describe 'premium access validation' do
    context 'with premium user' do
      let(:user) { create(:user, subscription_tier: 'premium') }

      before { sign_in user }

      describe 'GET #test_connection' do
        it 'allows access' do
          get :test_connection, params: { form_id: form.id }
          expect(response).not_to have_http_status(:forbidden)
        end
      end

      describe 'POST #create' do
        let(:valid_params) do
          {
            form_id: form.id,
            google_sheets_integration: {
              spreadsheet_id: 'test_id',
              sheet_name: 'Responses',
              auto_sync: true
            }
          }
        end

        it 'allows creating integration' do
          post :create, params: valid_params
          expect(response).not_to have_http_status(:forbidden)
        end
      end
    end

    context 'with admin user' do
      let(:user) { create(:user, role: 'admin', subscription_tier: 'basic') }

      before { sign_in user }

      describe 'GET #test_connection' do
        it 'allows access' do
          get :test_connection, params: { form_id: form.id }
          expect(response).not_to have_http_status(:forbidden)
        end
      end
    end

    context 'with basic user' do
      let(:user) { create(:user, subscription_tier: 'basic', role: 'user') }

      before { sign_in user }

      describe 'GET #test_connection' do
        it 'returns 403 forbidden' do
          get :test_connection, params: { form_id: form.id }
          expect(response).to have_http_status(:forbidden)
        end

        it 'returns premium upgrade information' do
          get :test_connection, params: { form_id: form.id }
          json_response = JSON.parse(response.body)
          
          expect(json_response['error']).to eq('Premium subscription required')
          expect(json_response['message']).to include('Premium subscription')
          expect(json_response['required_plan']).to eq('Premium')
          expect(json_response['upgrade_url']).to be_present
        end
      end

      describe 'POST #create' do
        let(:valid_params) do
          {
            form_id: form.id,
            google_sheets_integration: {
              spreadsheet_id: 'test_id',
              sheet_name: 'Responses',
              auto_sync: true
            }
          }
        end

        it 'returns 403 forbidden' do
          post :create, params: valid_params
          expect(response).to have_http_status(:forbidden)
        end

        it 'returns premium upgrade information' do
          post :create, params: valid_params
          json_response = JSON.parse(response.body)
          
          expect(json_response['error']).to eq('Premium subscription required')
          expect(json_response['upgrade_url']).to be_present
        end
      end

      describe 'POST #export' do
        let(:integration) { create(:google_sheets_integration, form: form) }

        it 'returns 403 forbidden' do
          post :export, params: { form_id: form.id }
          expect(response).to have_http_status(:forbidden)
        end
      end
    end

    context 'with another basic user scenario' do
      let(:user) { create(:user, subscription_tier: 'basic', role: 'user') }

      before { sign_in user }

      describe 'GET #test_connection' do
        it 'returns 403 forbidden' do
          get :test_connection, params: { form_id: form.id }
          expect(response).to have_http_status(:forbidden)
        end
      end
    end
  end
end