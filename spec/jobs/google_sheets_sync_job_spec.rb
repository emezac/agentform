require 'rails_helper'

RSpec.describe GoogleSheetsSyncJob, type: :job do
  let(:user) { create(:user) }
  let(:form) { create(:form, user: user) }
  let(:integration) { create(:google_sheets_integration, form: form) }
  let(:mock_service) { instance_double(Integrations::GoogleSheetsService) }

  before do
    allow(Integrations::GoogleSheetsService).to receive(:new).and_return(mock_service)
  end

  describe '#perform' do
    context 'with export_all action' do
      let(:success_result) { double('result', success?: true, failure?: false, value: 'Export completed') }

      before do
        allow(mock_service).to receive(:export_all_responses).and_return(success_result)
      end

      it 'calls export_all_responses on the service' do
        expect(mock_service).to receive(:export_all_responses)

        described_class.perform_now(form.id, 'export_all')
      end

      it 'logs success message' do
        expect(Rails.logger).to receive(:info).with(/Google Sheets sync completed/)

        described_class.perform_now(form.id, 'export_all')
      end
    end

    context 'with sync_response action' do
      let(:response) { create(:form_response, form: form) }
      let(:success_result) { double('result', success?: true, failure?: false, value: 'Response synced') }

      before do
        allow(mock_service).to receive(:sync_new_response).and_return(success_result)
      end

      it 'calls sync_new_response on the service' do
        expect(mock_service).to receive(:sync_new_response).with(response)

        described_class.perform_now(form.id, 'sync_response', response.id)
      end
    end

    context 'when integration cannot sync' do
      before do
        integration.update!(active: false)
      end

      it 'does not call the service' do
        expect(mock_service).not_to receive(:export_all_responses)

        described_class.perform_now(form.id, 'export_all')
      end
    end

    context 'when service returns failure' do
      let(:failure_result) { double('result', success?: false, failure?: true, error: 'API Error') }

      before do
        allow(mock_service).to receive(:export_all_responses).and_return(failure_result)
      end

      it 'logs error and raises exception' do
        expect(Rails.logger).to receive(:error).with(/Google Sheets sync failed/)

        expect {
          described_class.perform_now(form.id, 'export_all')
        }.to raise_error(StandardError, 'API Error')
      end
    end

    context 'with unknown action' do
      it 'raises ArgumentError' do
        expect {
          described_class.perform_now(form.id, 'unknown_action')
        }.to raise_error(ArgumentError, 'Unknown action: unknown_action')
      end
    end
  end

  describe 'retry behavior' do
    it 'retries on Google API client errors' do
      expect(described_class.retry_on_queue_adapter).to include(Google::Apis::ClientError)
    end

    it 'retries on standard errors' do
      expect(described_class.retry_on_queue_adapter).to include(StandardError)
    end
  end

  describe 'queue assignment' do
    it 'uses the integrations queue' do
      expect(described_class.queue_name).to eq('integrations')
    end
  end
end