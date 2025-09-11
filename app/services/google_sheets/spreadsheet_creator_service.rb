# frozen_string_literal: true

module GoogleSheets
  class SpreadsheetCreatorService < BaseService
    def initialize(integration:, form:, responses:, options: {})
      @integration = integration
      @form = form
      @responses = responses
      @options = options
      @user = integration.user
    end
    
    def call
      with_rate_limiting do
        spreadsheet = create_spreadsheet
        populate_data(spreadsheet.spreadsheet_id)
        format_spreadsheet(spreadsheet.spreadsheet_id)
        
        ServiceResult.success(
          spreadsheet_id: spreadsheet.spreadsheet_id,
          spreadsheet_url: spreadsheet.spreadsheet_url
        )
      end
    rescue Google::Apis::Error => e
      @integration.log_error(e)
      handle_google_api_error(e)
    rescue StandardError => e
      Rails.logger.error "Spreadsheet creation failed: #{e.message}"
      ServiceResult.failure(e.message)
    end
    
    private
    
    def create_spreadsheet
      spreadsheet_body = Google::Apis::SheetsV4::Spreadsheet.new(
        properties: Google::Apis::SheetsV4::SpreadsheetProperties.new(
          title: generate_spreadsheet_title,
          locale: 'en_US',
          time_zone: @user.time_zone || 'UTC'
        ),
        sheets: [create_main_sheet]
      )
      
      google_client(@integration).create_spreadsheet(spreadsheet_body)
    end
    
    def create_main_sheet
      Google::Apis::SheetsV4::Sheet.new(
        properties: Google::Apis::SheetsV4::SheetProperties.new(
          title: 'Form Responses',
          grid_properties: Google::Apis::SheetsV4::GridProperties.new(
            frozen_row_count: 1,
            frozen_column_count: 1
          )
        )
      )
    end
    
    def populate_data(spreadsheet_id)
      Rails.logger.info "Starting populate_data for form #{@form.id}"
      
      # Preparar headers
      headers = build_headers
      Rails.logger.info "Headers: #{headers.inspect}"
      
      # Escribir headers primero
      update_spreadsheet_batch(spreadsheet_id, [headers])
      Rails.logger.info "Headers written to spreadsheet"
      
      # Contar respuestas totales
      total_responses = @responses.count
      Rails.logger.info "Total responses to export: #{total_responses}"
      
      # Preparar filas de datos en lotes
      all_rows = []
      @responses.find_in_batches(batch_size: @options[:max_rows_per_batch]) do |batch|
        Rails.logger.info "Processing batch of #{batch.size} responses"
        batch.each do |response|
          all_rows << build_response_row(response)
        end
      end
      
      Rails.logger.info "Total rows prepared: #{all_rows.size}"
      
      # Escribir todas las filas de datos si hay respuestas
      if all_rows.any?
        Rails.logger.info "Writing #{all_rows.size} rows to spreadsheet"
        # Append data starting from row 2 (after headers)
        range = "Form Responses!A2:Z"
        value_range = Google::Apis::SheetsV4::ValueRange.new(values: all_rows)
        
        google_client(@integration).update_spreadsheet_values(
          spreadsheet_id,
          range,
          value_range,
          value_input_option: 'USER_ENTERED'
        )
        Rails.logger.info "Data successfully written to spreadsheet"
      else
        Rails.logger.warn "No rows to write to spreadsheet"
      end
    end
    
    def build_headers
      headers = ['Response ID', 'Submitted At', 'Status', 'IP Address']
      
      # Agregar headers de preguntas del formulario
      @form.form_questions.order(:position).each do |question|
        headers << question.title
      end
      
      # Agregar headers de preguntas dinámicas si está habilitado
      if @options[:include_dynamic_questions]
        headers += ['Dynamic Questions Count', 'Dynamic Responses']
      end
      
      headers
    end
    
    def build_response_row(response)
      Rails.logger.info "Building row for response #{response.id}"
      
      row = [
        response.id,
        response.completed_at&.strftime(@options[:date_format]) || 'In Progress',
        response.status.humanize,
        response.ip_address
      ]
      
      Rails.logger.info "Base row data: #{row.inspect}"
      
      # Agregar respuestas de preguntas del formulario
      @form.form_questions.order(:position).each do |question|
        answer = response.question_responses.find_by(form_question: question)
        answer_value = format_answer_value(answer&.answer_text)
        Rails.logger.info "Question '#{question.title}': answer = #{answer_value.inspect}"
        row << answer_value
      end
      
      # Agregar preguntas dinámicas si está habilitado
      if @options[:include_dynamic_questions]
        dynamic_count = response.dynamic_questions&.count || 0
        dynamic_responses = response.dynamic_questions&.map do |dq|
          "#{dq.title}: #{dq.answer_data}"
        end&.join(' | ') || ''
        
        row += [dynamic_count, dynamic_responses]
        Rails.logger.info "Added dynamic questions: count=#{dynamic_count}, responses=#{dynamic_responses}"
      end
      
      Rails.logger.info "Final row: #{row.inspect}"
      row
    end
    
    def format_answer_value(value)
      return @options[:empty_value] if value.blank?
      
      # Escapar valores que podrían causar problemas en hojas de cálculo
      value.to_s.gsub(/[\r\n]+/, ' ').strip
    end
    
    def update_spreadsheet_batch(spreadsheet_id, rows, range = "Form Responses!A1:Z")
      value_range = Google::Apis::SheetsV4::ValueRange.new(values: rows)
      
      google_client(@integration).update_spreadsheet_values(
        spreadsheet_id,
        range,
        value_range,
        value_input_option: 'USER_ENTERED'
      )
    end
    
    def format_spreadsheet(spreadsheet_id)
      requests = [
        create_header_format_request,
        create_autosize_request,
        create_freeze_request
      ]
      
      batch_update = Google::Apis::SheetsV4::BatchUpdateSpreadsheetRequest.new(
        requests: requests
      )
      
      google_client(@integration).batch_update_spreadsheet(spreadsheet_id, batch_update)
    end
    
    def create_header_format_request
      Google::Apis::SheetsV4::Request.new(
        repeat_cell: Google::Apis::SheetsV4::RepeatCellRequest.new(
          range: Google::Apis::SheetsV4::GridRange.new(
            sheet_id: 0,
            start_row_index: 0,
            end_row_index: 1
          ),
          cell: Google::Apis::SheetsV4::CellData.new(
            user_entered_format: Google::Apis::SheetsV4::CellFormat.new(
              background_color: Google::Apis::SheetsV4::Color.new(red: 0.9, green: 0.9, blue: 0.9),
              text_format: Google::Apis::SheetsV4::TextFormat.new(bold: true)
            )
          ),
          fields: 'userEnteredFormat(backgroundColor,textFormat)'
        )
      )
    end
    
    def create_autosize_request
      Google::Apis::SheetsV4::Request.new(
        auto_resize_dimensions: Google::Apis::SheetsV4::AutoResizeDimensionsRequest.new(
          dimensions: Google::Apis::SheetsV4::DimensionRange.new(
            sheet_id: 0,
            dimension: 'COLUMNS'
          )
        )
      )
    end
    
    def create_freeze_request
      Google::Apis::SheetsV4::Request.new(
        update_sheet_properties: Google::Apis::SheetsV4::UpdateSheetPropertiesRequest.new(
          properties: Google::Apis::SheetsV4::SheetProperties.new(
            sheet_id: 0,
            grid_properties: Google::Apis::SheetsV4::GridProperties.new(
              frozen_row_count: 1,
              frozen_column_count: 1
            )
          ),
          fields: 'gridProperties.frozenRowCount,gridProperties.frozenColumnCount'
        )
      )
    end
    
    def generate_spreadsheet_title
      timestamp = Time.current.strftime('%Y-%m-%d_%H-%M')
      "#{@form.name.truncate(50)} - Responses - #{timestamp}"
    end
  end
end