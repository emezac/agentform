require 'rails_helper'

RSpec.describe Integrations::GoogleSheetsService, type: :service do
  let(:user) { create(:user) }
  let(:form) { create(:form, user: user) }
  let(:integration) { create(:google_sheets_integration, form: form) }
  let(:service) { described_class.new(form, integration) }

  # Mock Google Sheets API
  let(:mock_sheets_service) { instance_double(Google::Apis::SheetsV4::SheetsService) }
  let(:mock_credentials) { instance_double(Google::Auth::ServiceAccountCredentials) }

  before do
    allow(Google::Apis::SheetsV4::SheetsService).to receive(:new).and_return(mock_sheets_service)
    allow(Google::Auth::ServiceAccountCredentials).to receive(:make_creds).and_return(mock_credentials)
    allow(mock_credentials).to receive(:fetch_access_token!)
    allow(mock_sheets_service).to receive(:authorization=)
  end

  describe '#create_spreadsheet' do
    let(:mock_spreadsheet) { double('spreadsheet', spreadsheet_id: 'test_spreadsheet_id') }

    before do
      allow(mock_sheets_service).to receive(:create_spreadsheet).and_return(mock_spreadsheet)
      allow(mock_sheets_service).to receive(:update_spreadsheet_values)
    end

    it 'creates a new spreadsheet with default title' do
      result = service.create_spreadsheet

      expect(result).to be_success
      expect(result.value[:spreadsheet_id]).to eq('test_spreadsheet_id')
      expect(result.value[:spreadsheet_url]).to include('test_spreadsheet_id')
    end

    it 'creates a spreadsheet with custom title' do
      custom_title = 'My Custom Form Responses'
      
      expect(mock_sheets_service).to receive(:create_spreadsheet) do |spreadsheet_config|
        expect(spreadsheet_config[:properties][:title]).to eq(custom_title)
        mock_spreadsheet
      end

      service.create_spreadsheet(custom_title)
    end

    it 'sets up headers after creating spreadsheet' do
      expect(mock_sheets_service).to receive(:update_spreadsheet_values)
        .with('test_spreadsheet_id', anything, anything, hash_including(value_input_option: 'RAW'))

      service.create_spreadsheet
    end

    context 'when API call fails' do
      before do
        allow(mock_sheets_service).to receive(:create_spreadsheet)
          .and_raise(Google::Apis::ClientError.new('API Error'))
      end

      it 'returns failure result' do
        result = service.create_spreadsheet

        expect(result).to be_failure
        expect(result.error).to include('Error creating spreadsheet')
      end
    end
  end

  describe '#export_all_responses' do
    let!(:question1) { create(:form_question, form: form, title: 'Name', position: 1) }
    let!(:question2) { create(:form_question, form: form, title: 'Email', position: 2) }
    let!(:response1) { create(:form_response, form: form, status: 'completed') }
    let!(:response2) { create(:form_response, form: form, status: 'completed') }

    before do
      create(:question_response, form_response: response1, form_question: question1, answer_data: { 'value' => 'John Doe' })
      create(:question_response, form_response: response1, form_question: question2, answer_data: { 'value' => 'john@example.com' })
      create(:question_response, form_response: response2, form_question: question1, answer_data: { 'value' => 'Jane Smith' })
      
      allow(mock_sheets_service).to receive(:clear_values)
      allow(mock_sheets_service).to receive(:append_spreadsheet_values)
    end

    context 'when integration can sync' do
      it 'exports all responses successfully' do
        result = service.export_all_responses

        expect(result).to be_success
        expect(result.value).to include('Exported 2 responses successfully')
      end

      it 'clears existing data before export' do
        expect(mock_sheets_service).to receive(:clear_values)
          .with(integration.spreadsheet_id, "#{integration.sheet_name}!A2:ZZ")

        service.export_all_responses
      end

      it 'appends response data to spreadsheet' do
        expect(mock_sheets_service).to receive(:append_spreadsheet_values) do |spreadsheet_id, range, value_range, options|
          expect(spreadsheet_id).to eq(integration.spreadsheet_id)
          expect(value_range.values).to have(2).items # 2 responses
          expect(value_range.values.first).to include('John Doe', 'john@example.com')
        end

        service.export_all_responses
      end

      it 'marks integration as successful' do
        service.export_all_responses

        expect(integration.reload.last_sync_at).to be_present
        expect(integration.error_message).to be_nil
        expect(integration.sync_count).to eq(1)
      end
    end

    context 'when integration cannot sync' do
      before do
        integration.update!(active: false)
      end

      it 'returns failure result' do
        result = service.export_all_responses

        expect(result).to be_failure
        expect(result.error).to eq('No integration configured')
      end
    end

    context 'when API call fails' do
      before do
        allow(mock_sheets_service).to receive(:clear_values)
          .and_raise(Google::Apis::ClientError.new('API Error'))
      end

      it 'marks integration as failed' do
        service.export_all_responses

        expect(integration.reload.error_message).to include('API Error')
        expect(integration.active?).to be_falsey
      end
    end
  end

  describe '#sync_new_response' do
    let!(:question) { create(:form_question, form: form, title: 'Name', position: 1) }
    let!(:response) { create(:form_response, form: form, status: 'completed') }

    before do
      create(:question_response, form_response: response, form_question: question, answer_data: { 'value' => 'John Doe' })
      allow(mock_sheets_service).to receive(:append_spreadsheet_values)
    end

    context 'when integration has auto_sync enabled' do
      before do
        integration.update!(auto_sync: true)
      end

      it 'syncs the response successfully' do
        result = service.sync_new_response(response)

        expect(result).to be_success
        expect(result.value).to eq('Response synced successfully')
      end

      it 'appends single response to spreadsheet' do
        expect(mock_sheets_service).to receive(:append_spreadsheet_values) do |spreadsheet_id, range, value_range, options|
          expect(value_range.values).to have(1).item
          expect(value_range.values.first).to include('John Doe')
        end

        service.sync_new_response(response)
      end
    end

    context 'when integration has auto_sync disabled' do
      before do
        integration.update!(auto_sync: false)
      end

      it 'does not sync the response' do
        expect(mock_sheets_service).not_to receive(:append_spreadsheet_values)
        
        result = service.sync_new_response(response)
        expect(result).to be_nil
      end
    end
  end

  describe '#build_headers' do
    let!(:question1) { create(:form_question, form: form, title: 'Name', position: 1) }
    let!(:question2) { create(:form_question, form: form, title: 'Email', position: 2) }

    it 'builds correct headers array' do
      headers = service.send(:build_headers)

      expect(headers).to eq(['Submitted At', 'Response ID', 'Name', 'Email'])
    end
  end

  describe '#format_answer_value' do
    let(:question) { create(:form_question, form: form, question_type: 'rating', config: { 'max_value' => 5 }) }
    let(:answer) { create(:question_response, answer_data: { 'value' => '4' }) }

    it 'formats rating answers correctly' do
      formatted = service.send(:format_answer_value, answer, question)
      expect(formatted).to eq('4/5')
    end

    it 'handles missing answers' do
      formatted = service.send(:format_answer_value, nil, question)
      expect(formatted).to eq('')
    end

    it 'formats checkbox arrays' do
      question.update!(question_type: 'checkbox')
      answer.update!(answer_data: { 'value' => ['Option 1', 'Option 2'] })
      
      formatted = service.send(:format_answer_value, answer, question)
      expect(formatted).to eq('Option 1, Option 2')
    end
  end
end