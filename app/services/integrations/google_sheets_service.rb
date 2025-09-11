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
      Rails.logger.info "Starting export for form #{@form.id} (#{@form.name})"
      
      # Validate form has questions
      if @form.form_questions.empty?
        return self.class.failure("Form has no questions to export")
      end
      
      # Load responses with proper associations
      responses = load_responses_for_export
      Rails.logger.info "Found #{responses.count} responses to export"
      
      # Validate responses have data
      responses_with_data = responses.select { |r| r.question_responses.any? }
      Rails.logger.info "#{responses_with_data.count} responses have answer data"
      
      if responses_with_data.empty?
        Rails.logger.warn "No responses with data found"
        return self.class.success("No responses with data to export")
      end
      
      # Clear and rebuild data
      clear_data_rows
      rows = build_response_rows(responses_with_data)
      
      Rails.logger.info "Built #{rows.size} data rows"
      rows.each_with_index do |row, index|
        Rails.logger.debug "Row #{index + 1}: #{row.inspect}"
      end
      
      append_rows(rows) if rows.any?
      
      @integration.mark_sync_success!
      self.class.success("Exported #{responses_with_data.count} responses successfully")
      
    rescue => e
      Rails.logger.error "Export failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      @integration.mark_sync_error!(e)
      self.class.failure("Export failed: #{e.message}")
    end
  end

  def sync_new_response(response)
    return unless @integration&.can_sync? && @integration.auto_sync?

    begin
      # Validate response has data and is in exportable status
      unless ['completed', 'partial'].include?(response.status)
        Rails.logger.info "Skipping sync for response #{response.id} with status: #{response.status}"
        return self.class.success("Response not in exportable status")
      end
      
      unless response.question_responses.any?
        Rails.logger.info "Skipping sync for response #{response.id} - no answer data"
        return self.class.success("Response has no answer data")
      end
      
      # Ensure response is loaded with proper associations
      response = @form.form_responses
                      .includes(question_responses: :form_question)
                      .find(response.id)
      
      row = build_response_row(response)
      append_rows([row])
      
      self.class.success("Response synced successfully")
    rescue => e
      Rails.logger.error "Google Sheets sync failed for response #{response.id}: #{e.message}"
      self.class.failure("Sync failed: #{e.message}")
    end
  end

  private

  def load_responses_for_export
    @form.form_responses
      .includes(question_responses: :form_question)
      .where(status: ['completed', 'partial'])
      .order(created_at: :desc)
  end

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
    Rails.logger.info "Building row for response #{response.id} (status: #{response.status})"
    
    row = [
      response.created_at.strftime('%Y-%m-%d %H:%M:%S'),
      response.id
    ]

    @form.form_questions.order(:position).each do |question|
      answer = response.question_responses.find_by(form_question_id: question.id)
      Rails.logger.info "Question '#{question.title}' (ID: #{question.id}): found answer = #{answer.present?}"
      
      if answer.present?
        Rails.logger.info "Answer data: #{answer.answer_data.inspect}"
        Rails.logger.info "Answer text: #{answer.answer_text.inspect}"
      end
      
      formatted_value = format_answer_value(answer, question)
      Rails.logger.info "Question '#{question.title}': formatted value = #{formatted_value.inspect}"
      row << formatted_value
    end

    Rails.logger.info "Final row: #{row.inspect}"
    row
  end

  def format_answer_value(answer, question)
    Rails.logger.debug "Formatting answer for question #{question.id}: #{answer.inspect}"
    
    return '' unless answer.present?

    # Use the formatted_answer method from QuestionResponse model
    formatted_value = answer.formatted_answer
    Rails.logger.debug "Formatted answer: #{formatted_value.inspect}"
    
    return '' if formatted_value.blank?
    
    formatted_value.to_s
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