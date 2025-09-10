require 'rails_helper'

RSpec.describe GoogleSheetsIntegration, type: :model do
  let(:user) { create(:user) }
  let(:form) { create(:form, user: user) }
  let(:integration) { create(:google_sheets_integration, form: form) }

  describe 'associations' do
    it { should belong_to(:form) }
  end

  describe 'validations' do
    it { should validate_presence_of(:spreadsheet_id) }
    it { should validate_presence_of(:sheet_name) }
  end

  describe 'scopes' do
    let!(:active_integration) { create(:google_sheets_integration, form: form, active: true) }
    let!(:inactive_integration) { create(:google_sheets_integration, form: form, active: false) }
    let!(:auto_sync_integration) { create(:google_sheets_integration, form: form, auto_sync: true) }

    describe '.active' do
      it 'returns only active integrations' do
        expect(GoogleSheetsIntegration.active).to include(active_integration)
        expect(GoogleSheetsIntegration.active).not_to include(inactive_integration)
      end
    end

    describe '.auto_sync_enabled' do
      it 'returns only auto-sync enabled integrations' do
        expect(GoogleSheetsIntegration.auto_sync_enabled).to include(auto_sync_integration)
      end
    end
  end

  describe '#spreadsheet_url' do
    it 'returns the correct Google Sheets URL' do
      expected_url = "https://docs.google.com/spreadsheets/d/#{integration.spreadsheet_id}/edit"
      expect(integration.spreadsheet_url).to eq(expected_url)
    end
  end

  describe '#mark_sync_success!' do
    it 'updates sync metadata' do
      freeze_time do
        integration.mark_sync_success!
        
        expect(integration.last_sync_at).to eq(Time.current)
        expect(integration.error_message).to be_nil
        expect(integration.sync_count).to eq(1)
      end
    end

    it 'increments sync count' do
      integration.update!(sync_count: 5)
      integration.mark_sync_success!
      
      expect(integration.sync_count).to eq(6)
    end
  end

  describe '#mark_sync_error!' do
    let(:error_message) { 'API rate limit exceeded' }

    it 'records error and deactivates integration' do
      integration.mark_sync_error!(error_message)
      
      expect(integration.error_message).to eq(error_message)
      expect(integration.active?).to be_falsey
    end
  end

  describe '#can_sync?' do
    context 'when integration is active and has spreadsheet_id' do
      it 'returns true' do
        expect(integration.can_sync?).to be_truthy
      end
    end

    context 'when integration is inactive' do
      it 'returns false' do
        integration.update!(active: false)
        expect(integration.can_sync?).to be_falsey
      end
    end

    context 'when spreadsheet_id is blank' do
      it 'returns false' do
        integration.update_columns(spreadsheet_id: '')
        expect(integration.can_sync?).to be_falsey
      end
    end
  end
end