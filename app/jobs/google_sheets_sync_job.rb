class GoogleSheetsSyncJob < ApplicationJob
  queue_as :integrations
  
  retry_on Google::Apis::ClientError, wait: :exponentially_longer, attempts: 3
  retry_on StandardError, wait: 5.seconds, attempts: 2

  def perform(form_id, action = 'export_all', response_id = nil)
    form = Form.find(form_id)
    integration = form.google_sheets_integration
    
    return unless integration&.can_sync?

    service = Integrations::GoogleSheetsService.new(form, integration)
    
    case action
    when 'export_all'
      result = service.export_all_responses
    when 'sync_response'
      response = form.form_responses.find(response_id)
      result = service.sync_new_response(response)
    else
      raise ArgumentError, "Unknown action: #{action}"
    end

    if result.failure?
      Rails.logger.error "Google Sheets sync failed for form #{form_id}: #{result.error}"
      raise StandardError, result.error
    end

    Rails.logger.info "Google Sheets sync completed for form #{form_id}: #{result.value}"
  end
end