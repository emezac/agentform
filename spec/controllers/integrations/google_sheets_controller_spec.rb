require 'rails_helper'

RSpec.describe Integrations::GoogleSheetsController, type: :controller do
  let(:user) { create(:user) }
  let(:form) { create(:form, user: user) }

  before do
    sign_in user
  end

  describe 'GET #show' do
    context 'when integration exists' do
      let!(:integration) { create(:google_sheets_integration, form: form) }

      it 'returns integration details' do
        get :show, params: { form_id: form.id }

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['integration']['id']).to eq(integration.id)
        expect(json_response['spreadsheet_url']).to be_present
      end
    end

    context 'when integration does not exist' do
      it 'returns not found' do
        get :show, params: { form_id: form.id }

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST #create' do
    let(:valid_params) do
      {
        form_id: form.id,
        google_sheets_integration: {
          spreadsheet_id: 'test_spreadsheet_id',
          sheet_name: 'Responses',
          auto_sync: true
        }
      }
    end

    context 'with valid parameters' do
      it 'creates a new integration' do
        expect {
          post :create, params: valid_params
        }.to change(GoogleSheetsIntegration, :count).by(1)

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['message']).to include('configured successfully')
      end
    end

    context 'when creating new spreadsheet' do
      let(:mock_service) { instance_double(Integrations::GoogleSheetsService) }
      let(:success_result) { double('result', success?: true, value: { spreadsheet_id: 'new_id', spreadsheet_url: 'test_url' }) }

      before do
        allow(Integrations::GoogleSheetsService).to receive(:new).and_return(mock_service)
        allow(mock_service).to receive(:create_spreadsheet).and_return(success_result)
      end

      it 'creates new spreadsheet and integration' do
        params = valid_params.merge(
          create_new_spreadsheet: true,
          spreadsheet_title: 'My Form Responses'
        )

        expect(mock_service).to receive(:create_spreadsheet).with('My Form Responses')

        post :create, params: params

        expect(response).to have_http_status(:success)
        integration = form.reload.google_sheets_integration
        expect(integration.spreadsheet_id).to eq('new_id')
      end
    end

    context 'with invalid parameters' do
      it 'returns validation errors' do
        invalid_params = valid_params.deep_merge(
          google_sheets_integration: { spreadsheet_id: '' }
        )

        post :create, params: invalid_params

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to be_present
      end
    end

    context 'when export_existing is requested' do
      it 'enqueues export job' do
        params = valid_params.merge(export_existing: true)

        expect(GoogleSheetsSyncJob).to receive(:perform_later).with(form.id, 'export_all')

        post :create, params: params
      end
    end
  end

  describe 'PATCH #update' do
    let!(:integration) { create(:google_sheets_integration, form: form) }

    it 'updates integration settings' do
      patch :update, params: {
        form_id: form.id,
        google_sheets_integration: {
          sheet_name: 'Updated Responses',
          auto_sync: false
        }
      }

      expect(response).to have_http_status(:success)
      integration.reload
      expect(integration.sheet_name).to eq('Updated Responses')
      expect(integration.auto_sync?).to be_falsey
    end
  end

  describe 'DELETE #destroy' do
    let!(:integration) { create(:google_sheets_integration, form: form) }

    it 'removes the integration' do
      expect {
        delete :destroy, params: { form_id: form.id }
      }.to change(GoogleSheetsIntegration, :count).by(-1)

      expect(response).to have_http_status(:success)
    end
  end

  describe 'POST #export' do
    let!(:integration) { create(:google_sheets_integration, form: form) }

    context 'when integration can sync' do
      it 'enqueues export job' do
        expect(GoogleSheetsSyncJob).to receive(:perform_later).with(form.id, 'export_all')

        post :export, params: { form_id: form.id }

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['message']).to include('Export started')
      end
    end

    context 'when integration cannot sync' do
      before do
        integration.update!(active: false)
      end

      it 'returns error' do
        post :export, params: { form_id: form.id }

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('not active')
      end
    end
  end

  describe 'POST #toggle_auto_sync' do
    let!(:integration) { create(:google_sheets_integration, form: form, auto_sync: false) }

    it 'toggles auto_sync setting' do
      post :toggle_auto_sync, params: { form_id: form.id }

      expect(response).to have_http_status(:success)
      integration.reload
      expect(integration.auto_sync?).to be_truthy

      json_response = JSON.parse(response.body)
      expect(json_response['auto_sync']).to be_truthy
      expect(json_response['message']).to include('enabled')
    end
  end

  describe 'POST #test_connection' do
    let(:mock_service) { instance_double(Integrations::GoogleSheetsService) }

    before do
      allow(Integrations::GoogleSheetsService).to receive(:new).and_return(mock_service)
    end

    context 'when connection is successful' do
      let(:success_result) { double('result', success?: true, value: { spreadsheet_id: 'test_id' }) }

      before do
        allow(mock_service).to receive(:create_spreadsheet).and_return(success_result)
      end

      it 'returns success response' do
        post :test_connection, params: { form_id: form.id }

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be_truthy
        expect(json_response['message']).to include('successful')
      end
    end

    context 'when connection fails' do
      let(:failure_result) { double('result', success?: false, error: 'API Error') }

      before do
        allow(mock_service).to receive(:create_spreadsheet).and_return(failure_result)
      end

      it 'returns failure response' do
        post :test_connection, params: { form_id: form.id }

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be_falsey
        expect(json_response['error']).to eq('API Error')
      end
    end
  end
end