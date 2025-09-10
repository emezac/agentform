require 'rails_helper'

RSpec.describe 'Google Sheets Integration', type: :system do
  let(:user) { create(:user) }
  let(:form) { create(:form, user: user) }

  before do
    sign_in user
    
    # Mock Google Sheets API
    allow_any_instance_of(Integrations::GoogleSheetsService).to receive(:authorize_service)
    
    visit edit_form_path(form)
  end

  describe 'Setting up integration' do
    context 'when no integration exists' do
      it 'shows setup form' do
        within('[data-controller="google-sheets-integration"]') do
          expect(page).to have_text('No Google Sheets integration')
          expect(page).to have_text('Connect your form to automatically export responses')
          expect(page).to have_button('Connect to Google Sheets')
        end
      end

      it 'allows creating new spreadsheet', js: true do
        mock_service = instance_double(Integrations::GoogleSheetsService)
        success_result = double('result', 
          success?: true, 
          value: { 
            spreadsheet_id: 'new_spreadsheet_id',
            spreadsheet_url: 'https://docs.google.com/spreadsheets/d/new_spreadsheet_id/edit'
          }
        )
        
        allow(Integrations::GoogleSheetsService).to receive(:new).and_return(mock_service)
        allow(mock_service).to receive(:create_spreadsheet).and_return(success_result)

        within('[data-controller="google-sheets-integration"]') do
          choose 'Create new spreadsheet'
          fill_in 'Spreadsheet Title', with: 'My Custom Form Responses'
          fill_in 'Sheet Name', with: 'Form Data'
          check 'Enable auto-sync for new responses'
          
          click_button 'Connect to Google Sheets'
        end

        expect(page).to have_text('Google Sheets integration configured successfully')
      end

      it 'allows using existing spreadsheet', js: true do
        within('[data-controller="google-sheets-integration"]') do
          choose 'Use existing spreadsheet'
          fill_in 'Spreadsheet ID', with: '1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms'
          fill_in 'Sheet Name', with: 'Responses'
          
          click_button 'Connect to Google Sheets'
        end

        expect(page).to have_text('Google Sheets integration configured successfully')
      end
    end

    context 'when testing connection', js: true do
      it 'shows success message for valid connection' do
        mock_service = instance_double(Integrations::GoogleSheetsService)
        success_result = double('result', 
          success?: true,
          value: { spreadsheet_id: 'test_id' }
        )
        
        allow(Integrations::GoogleSheetsService).to receive(:new).and_return(mock_service)
        allow(mock_service).to receive(:create_spreadsheet).and_return(success_result)

        within('[data-controller="google-sheets-integration"]') do
          click_button 'Test Connection'
        end

        expect(page).to have_text('Connection successful!')
      end

      it 'shows error message for failed connection' do
        mock_service = instance_double(Integrations::GoogleSheetsService)
        
        allow(Integrations::GoogleSheetsService).to receive(:new).and_return(mock_service)
        allow(mock_service).to receive(:create_spreadsheet).and_raise(StandardError.new('API Error'))

        within('[data-controller="google-sheets-integration"]') do
          click_button 'Test Connection'
        end

        expect(page).to have_text('Connection failed')
      end
    end
  end

  describe 'Managing existing integration' do
    let!(:integration) { create(:google_sheets_integration, form: form) }

    before do
      visit edit_form_path(form)
    end

    it 'shows connected status' do
      within('[data-controller="google-sheets-integration"]') do
        expect(page).to have_text('Connected')
        expect(page).to have_link('Open', href: integration.spreadsheet_url)
        expect(page).to have_button('Export Now')
        expect(page).to have_button('Disconnect')
      end
    end

    it 'allows manual export', js: true do
      expect(GoogleSheetsSyncJob).to receive(:perform_later).with(form.id, 'export_all')

      within('[data-controller="google-sheets-integration"]') do
        click_button 'Export Now'
      end

      expect(page).to have_text('Export started')
    end

    it 'allows toggling auto-sync', js: true do
      within('[data-controller="google-sheets-integration"]') do
        check 'Auto-sync new responses'
      end

      expect(page).to have_text('Auto-sync enabled')
      
      integration.reload
      expect(integration.auto_sync?).to be_truthy
    end

    it 'allows disconnecting integration', js: true do
      accept_confirm do
        within('[data-controller="google-sheets-integration"]') do
          click_button 'Disconnect'
        end
      end

      expect(page).to have_text('Google Sheets integration removed')
      expect(form.reload.google_sheets_integration).to be_nil
    end

    context 'when integration has errors' do
      let!(:integration) { create(:google_sheets_integration, :with_error, form: form) }

      it 'displays error message' do
        within('[data-controller="google-sheets-integration"]') do
          expect(page).to have_text('Sync Error')
          expect(page).to have_text('API rate limit exceeded')
        end
      end
    end

    context 'when integration was recently synced' do
      let!(:integration) { create(:google_sheets_integration, :recently_synced, form: form) }

      it 'shows last sync time' do
        within('[data-controller="google-sheets-integration"]') do
          expect(page).to have_text('Last sync: about 1 hour ago')
        end
      end
    end
  end

  describe 'Auto-sync behavior' do
    let!(:integration) { create(:google_sheets_integration, :with_auto_sync, form: form) }
    let!(:question) { create(:form_question, form: form) }

    it 'triggers sync when response is completed' do
      response = create(:form_response, form: form, status: 'in_progress')
      
      expect(GoogleSheetsSyncJob).to receive(:perform_later).with(form.id, 'sync_response', response.id)
      
      response.update!(status: 'completed')
    end

    it 'does not trigger sync for non-completed responses' do
      response = create(:form_response, form: form, status: 'in_progress')
      
      expect(GoogleSheetsSyncJob).not_to receive(:perform_later)
      
      response.update!(last_activity_at: Time.current)
    end
  end
end