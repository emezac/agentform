# frozen_string_literal: true

class Forms::ExportsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_form
  before_action :ensure_premium_user
  before_action :ensure_google_connected
  
  def google_sheets
    if @form.form_responses.empty?
      return redirect_to form_responses_path(@form), 
                         alert: 'No responses available for export.'
    end
    
    result = GoogleSheets::ExportService.call(
      user: current_user,
      form: @form,
      options: export_options
    )
    
    if result.success?
      redirect_to form_responses_path(@form), 
                  notice: 'Export to Google Sheets has started. You will be notified when complete.'
    else
      redirect_to form_responses_path(@form), 
                  alert: "Export failed: #{result.errors.join(', ')}"
    end
  end
  
  def status
    export_job = current_user.export_jobs.find_by(job_id: params[:job_id])
    
    if export_job
      render json: {
        status: export_job.status,
        progress: export_job.progress_percentage,
        spreadsheet_url: export_job.spreadsheet_url,
        records_exported: export_job.records_exported,
        error_message: export_job.error_details&.dig('message')
      }
    else
      render json: { error: 'Export job not found' }, status: :not_found
    end
  end
  
  private
  
  def set_form
    @form = current_user.forms.find(params[:form_id])
  end
  
  def ensure_premium_user
    unless current_user.premium?
      redirect_to subscription_management_path, 
                  alert: 'Google Sheets export requires a Premium subscription.'
    end
  end
  
  def ensure_google_connected
    unless current_user.google_integration&.active?
      redirect_to google_integration_path, 
                  alert: 'Please connect your Google account first.'
    end
  end
  
  def export_options
    {
      include_metadata: params[:include_metadata] == '1',
      include_timestamps: params[:include_timestamps] == '1',
      include_dynamic_questions: params[:include_dynamic_questions] == '1',
      date_format: params[:date_format] || '%Y-%m-%d %H:%M:%S'
    }
  end
end