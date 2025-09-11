require 'google/apis/sheets_v4'
require 'googleauth'

class Integrations::GoogleSheetsService < ApplicationService
  # Simple Result classes for this service
  class Result
    attr_reader :value, :error
    
    def initialize(value: nil, error: nil)
      @value = value
      @error = error
    end
    
    def success?
      @error.nil?
    end
    
    def failure?
      !success?
    end
  end
  
  def self.success(value)
    Result.new(value: value)
  end
  
  def self.failure(error)
    Result.new(error: error)
  end
  def initialize(form, integration = nil)
    @form = form
    @integration = integration || form.google_sheets_integration
    @service = Google::Apis::SheetsV4::SheetsService.new
    @service.authorization = authorize_service
  end

  def create_spreadsheet(title = nil)
    title ||= "#{@form.name} - Responses"
    
    spreadsheet = {
      properties: {
        title: title
      },
      sheets: [{
        properties: {
          title: 'Responses'
        }
      }]
    }

    result = @service.create_spreadsheet(spreadsheet)
    
    # Create headers
    setup_headers(result.spreadsheet_id)
    
    self.class.success({
      spreadsheet_id: result.spreadsheet_id,
      spreadsheet_url: "https://docs.google.com/spreadsheets/d/#{result.spreadsheet_id}/edit"
    })
  rescue => e
    self.class.failure("Error creating spreadsheet: #{e.message}")
  end

  def export_all_responses
    return self.class.failure("No integration configured") unless @integration&.can_sync?

    begin
      # Clear existing data (except headers)
      clear_data_rows
      
      # Get all responses
      responses = @form.form_responses.includes(:question_responses)
      
      if responses.any?
        rows = build_response_rows(responses)
        append_rows(rows)
      end

      @integration.mark_sync_success!
      self.class.success("Exported #{responses.count} responses successfully")
    rescue => e
      @integration.mark_sync_error!(e)
      self.class.failure("Export failed: #{e.message}")
    end
  end

  def sync_new_response(response)
    return unless @integration&.can_sync? && @integration.auto_sync?

    begin
      row = build_response_row(response)
      append_rows([row])
      
      self.class.success("Response synced successfully")
    rescue => e
      Rails.logger.error "Google Sheets sync failed for response #{response.id}: #{e.message}"
      self.class.failure("Sync failed: #{e.message}")
    end
  end

  private

  def authorize_service
    # Use user's OAuth token if available, fallback to service account
    user_integration = @form.user.google_integration
    
    if user_integration&.valid_token?
      # Use user's OAuth2 credentials
      Signet::OAuth2::Client.new(
        access_token: user_integration.access_token,
        refresh_token: user_integration.refresh_token,
        client_id: GoogleSheets::ConfigService.oauth_client_id,
        client_secret: GoogleSheets::ConfigService.oauth_client_secret,
        token_credential_uri: 'https://oauth2.googleapis.com/token'
      )
    else
      # Fallback to service account (for system operations)
      if Rails.application.credentials.google_sheets.present?
        credentials = Google::Auth::ServiceAccountCredentials.make_creds(
          json_key_io: StringIO.new(Rails.application.credentials.google_sheets.to_json),
          scope: Google::Apis::SheetsV4::AUTH_SPREADSHEETS
        )
        credentials.fetch_access_token!
        credentials
      else
        raise "No Google authentication available. User must connect their Google account first."
      end
    end
  end

  def setup_headers(spreadsheet_id)
    headers = build_headers
    
    range = "#{@integration&.sheet_name || 'Responses'}!A1"
    value_range = Google::Apis::SheetsV4::ValueRange.new(
      values: [headers]
    )

    @service.update_spreadsheet_value(
      spreadsheet_id,
      range,
      value_range,
      value_input_option: 'RAW'
    )
  end

  def build_headers
    headers = ['Submitted At', 'Response ID']
    
    @form.form_questions.order(:position).each do |question|
      headers << question.title
    end
    
    headers
  end

  def build_response_rows(responses)
    responses.map { |response| build_response_row(response) }
  end

  def build_response_row(response)
    row = [
      response.created_at.strftime('%Y-%m-%d %H:%M:%S'),
      response.id
    ]

    @form.form_questions.order(:position).each do |question|
      answer = response.question_responses.find { |a| a.form_question_id == question.id }
      row << format_answer_value(answer, question)
    end

    row
  end

  def format_answer_value(answer, question)
    return '' unless answer&.answer_data.present?

    value = answer.answer_data['value'] || answer.answer_data

    case question.question_type
    when 'rating'
      max_value = question.question_config&.dig('max_value') || 5
      "#{value}/#{max_value}"
    when 'multiple_choice'
      value.to_s
    when 'checkbox'
      value.is_a?(Array) ? value.join(', ') : value.to_s
    when 'date'
      Date.parse(value.to_s).strftime('%Y-%m-%d') rescue value.to_s
    else
      value.to_s
    end
  end

  def clear_data_rows
    # Get current data to determine range
    range = "#{@integration.sheet_name}!A2:ZZ"
    
    begin
      @service.clear_values(
        @integration.spreadsheet_id,
        range
      )
    rescue Google::Apis::ClientError => e
      # Sheet might not exist or be empty, that's ok
      Rails.logger.warn "Could not clear sheet data: #{e.message}"
    end
  end

  def append_rows(rows)
    return if rows.empty?

    range = "#{@integration.sheet_name}!A:A"
    value_range = Google::Apis::SheetsV4::ValueRange.new(
      values: rows
    )

    @service.append_spreadsheet_value(
      @integration.spreadsheet_id,
      range,
      value_range,
      value_input_option: 'RAW'
    )
  end
end