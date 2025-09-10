# frozen_string_literal: true

module GoogleSheets
  class ExportService < BaseService
    def initialize(user:, form:, options: {})
      @user = user
      @form = form
      @options = default_options.merge(options)
      @integration = user.google_integration
      @export_job = nil
    end
    
    def call
      return ServiceResult.failure("User is not premium") unless @user.premium?
      return ServiceResult.failure("Google integration not found") unless @integration
      return ServiceResult.failure("Google integration not active") unless @integration.active?
      
      create_export_job
      GoogleSheetsExportJob.perform_async(@export_job.id)
      
      ServiceResult.success(export_job: @export_job)
    rescue StandardError => e
      Rails.logger.error "Google Sheets export failed: #{e.message}"
      @export_job&.update!(status: :failed, error_details: { message: e.message })
      ServiceResult.failure(e.message)
    end
    
    private
    
    def create_export_job
      @export_job = ExportJob.create!(
        user: @user,
        form: @form,
        job_id: SecureRandom.uuid,
        export_type: 'google_sheets',
        configuration: @options,
        status: :pending
      )
    end
    
    def default_options
      {
        include_metadata: true,
        include_timestamps: true,
        include_dynamic_questions: true,
        date_format: '%Y-%m-%d %H:%M:%S',
        empty_value: '',
        max_rows_per_batch: 1000
      }
    end
  end
end