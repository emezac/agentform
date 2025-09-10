# frozen_string_literal: true

class GoogleSheetsExportJob < ApplicationJob
  queue_as :google_sheets
  
  retry_on Google::Apis::RateLimitError, wait: :exponentially_longer, attempts: 5
  retry_on Google::Apis::ServerError, wait: 30.seconds, attempts: 3
  
  discard_on Google::Apis::AuthorizationError do |job, error|
    export_job = ExportJob.find(job.arguments.first)
    export_job.update!(
      status: :failed,
      error_details: { 
        type: 'authorization_error',
        message: 'Google authorization expired. User needs to reconnect.'
      }
    )
    
    # TODO: Implement GoogleSheetsMailer.authorization_expired
    # GoogleSheetsMailer.authorization_expired(export_job.user).deliver_now
  end
  
  def perform(export_job_id)
    @export_job = ExportJob.find(export_job_id)
    @export_job.update!(status: :processing, started_at: Time.current)
    
    # Verificaciones previas
    return fail_job("User is not premium") unless @export_job.user.premium?
    return fail_job("Form not found") unless @export_job.form
    
    integration = @export_job.user.google_integration
    return fail_job("Google integration not found") unless integration&.active?
    
    # Obtener respuestas del formulario
    responses = @export_job.form.form_responses.includes(:question_responses, :dynamic_questions)
    
    if responses.empty?
      return complete_job_with_warning("No responses found for export")
    end
    
    # Crear la hoja de cálculo
    result = GoogleSheets::SpreadsheetCreatorService.call(
      integration: integration,
      form: @export_job.form,
      responses: responses,
      options: @export_job.configuration
    )
    
    if result.success?
      complete_job_successfully(result.result)
    else
      fail_job(result.errors.join(', '))
    end
    
  rescue StandardError => e
    Rails.logger.error "GoogleSheetsExportJob failed: #{e.message}\n#{e.backtrace.join("\n")}"
    fail_job("Unexpected error: #{e.message}")
    raise e # Re-raise para que Sidekiq pueda manejar el reintento
  end
  
  private
  
  def complete_job_successfully(result)
    @export_job.update!(
      status: :completed,
      completed_at: Time.current,
      spreadsheet_id: result[:spreadsheet_id],
      spreadsheet_url: result[:spreadsheet_url],
      records_exported: @export_job.form.form_responses.count
    )
    
    # TODO: Implement GoogleSheetsMailer.export_completed
    # GoogleSheetsMailer.export_completed(@export_job).deliver_now
    
    # Audit trail
    AuditLog.create!(
      user: @export_job.user,
      event_type: 'google_sheets_export_completed',
      details: {
        form_id: @export_job.form.id,
        spreadsheet_url: result[:spreadsheet_url],
        records_exported: @export_job.records_exported
      }
    )
  end
  
  def complete_job_with_warning(message)
    @export_job.update!(
      status: :completed,
      completed_at: Time.current,
      error_details: { type: 'warning', message: message }
    )
    
    # TODO: Implement GoogleSheetsMailer.export_completed_with_warning
    # GoogleSheetsMailer.export_completed_with_warning(@export_job, message).deliver_now
  end
  
  def fail_job(error_message)
    @export_job.update!(
      status: :failed,
      completed_at: Time.current,
      error_details: { 
        type: 'job_error',
        message: error_message,
        timestamp: Time.current
      }
    )
    
    # TODO: Implement GoogleSheetsMailer.export_failed
    # GoogleSheetsMailer.export_failed(@export_job, error_message).deliver_now
  end
end