# frozen_string_literal: true

module GoogleSheets
  class ConnectionTestService < BaseService
    def initialize(integration:)
      @integration = integration
      @user = integration.user
    end
    
    def call
      with_rate_limiting do
        # Intentar hacer una llamada simple a la API para verificar la conexión
        test_api_connection
        
        ServiceResult.success(
          user_info: @integration.user_info,
          last_used: @integration.last_used_at,
          usage_count: @integration.usage_count
        )
      end
    rescue Google::Apis::Error => e
      @integration.log_error(e)
      handle_google_api_error(e)
    rescue StandardError => e
      Rails.logger.error "Connection test failed: #{e.message}"
      ServiceResult.failure(e.message)
    end
    
    private
    
    def test_api_connection
      # Crear una hoja de cálculo de prueba muy simple
      spreadsheet_body = Google::Apis::SheetsV4::Spreadsheet.new(
        properties: Google::Apis::SheetsV4::SpreadsheetProperties.new(
          title: "AgentForm Connection Test - #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}"
        )
      )
      
      # Crear la hoja de cálculo
      spreadsheet = google_client(@integration).create_spreadsheet(spreadsheet_body)
      
      # Inmediatamente eliminarla (usando Drive API si está disponible)
      begin
        drive_service = Google::Apis::DriveV3::DriveService.new
        drive_service.authorization = build_authorization(@integration)
        drive_service.delete_file(spreadsheet.spreadsheet_id)
      rescue StandardError => e
        Rails.logger.warn "Could not delete test spreadsheet: #{e.message}"
        # No es crítico si no podemos eliminar la hoja de prueba
      end
      
      # Registrar el uso exitoso
      @integration.record_usage!
    end
  end
end