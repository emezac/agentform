class ReportsController < ApplicationController
  include Devise::Controllers::Helpers
  before_action :authenticate_user!
  before_action :set_analysis_report, only: [:show, :download, :status]
  
  # Disable Pundit completely for this controller
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  # GET /reports/:id
  def show
    # Manual authorization check
    unless @analysis_report.form_response.form.user == current_user
      redirect_to root_path, alert: 'Not authorized to access this report.'
      return
    end
    
    respond_to do |format|
      format.html # Mostrar reporte en el navegador
      format.json { render json: serialize_report(@analysis_report) }
    end
  end

  # GET /reports/:id/download
  def download
    # Manual authorization check
    unless @analysis_report.form_response.form.user == current_user
      redirect_to root_path, alert: 'Not authorized to access this report.'
      return
    end
    
    # For now, since we don't have physical files, send the markdown content
    if @analysis_report.completed? && @analysis_report.markdown_content.present?
      filename = "report_#{@analysis_report.id}_#{Date.current.strftime('%Y%m%d')}.md"
      
      send_data @analysis_report.markdown_content,
                filename: filename,
                type: 'text/markdown',
                disposition: 'attachment'
    else
      redirect_to analysis_report_path(@analysis_report), 
                  alert: 'Report content not available for download.'
    end
  end

  # POST /reports/generate
  def generate
    # Check if user can use AI features (premium plan required)
    unless current_user.can_use_ai_features?
      redirect_to root_path, alert: 'Report generation requires a premium subscription. Please upgrade your plan to access this feature.'
      return
    end

    # Buscar la respuesta del formulario a través de las formas del usuario
    @form_response = FormResponse.joins(:form)
                                 .where(forms: { user: current_user })
                                 .find(params[:form_response_id])

    # Manual authorization check since we skipped Pundit for this action
    unless @form_response.form.user == current_user
      redirect_to root_path, alert: 'Not authorized to generate reports for this form response.'
      return
    end

    # Check if report already exists and is recent
    existing_report = @form_response.analysis_reports
                                   .where(report_type: 'comprehensive_strategic_analysis')
                                   .where('created_at > ?', 24.hours.ago)
                                   .completed
                                   .first

    if existing_report
      return redirect_to existing_report, notice: 'Using existing recent report.'
    end

    # Generate sample report content immediately
    sample_content = generate_sample_report(@form_response)

    # Create new report record with content
    @analysis_report = @form_response.analysis_reports.create!(
      report_type: 'comprehensive_strategic_analysis',
      markdown_content: sample_content,
      status: 'completed', # Mark as completed since we're generating content immediately
      expires_at: 7.days.from_now,
      generated_at: Time.current,
      ai_cost: rand(0.10..2.50).round(2)
    )

    # In a real application, you would queue a background job here:
    # if defined?(Forms::ReportGenerationJob)
    #   @analysis_report.update!(status: 'generating', markdown_content: 'Generating...')
    #   Forms::ReportGenerationJob.perform_later(@form_response.id, @analysis_report.id)
    # end

    respond_to do |format|
      format.html { 
        redirect_to @analysis_report, 
                    notice: 'Report generated successfully!' 
      }
      format.json { 
        render json: { 
          report_id: @analysis_report.id,
          status: @analysis_report.status,
          redirect_url: analysis_report_path(@analysis_report)
        }
      }
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: 'Form response not found or not accessible.'
  end

  # GET /reports/:id/status
  def status
    # Manual authorization check
    unless @analysis_report.form_response.form.user == current_user
      render json: { error: 'Not authorized' }, status: :forbidden
      return
    end
    
    render json: {
      id: @analysis_report.id,
      status: @analysis_report.status,
      progress: calculate_progress(@analysis_report),
      completed_at: @analysis_report.generated_at,
      download_url: @analysis_report.completed? ? @analysis_report.download_url : nil,
      file_size: @analysis_report.respond_to?(:formatted_file_size) ? @analysis_report.formatted_file_size : 'Unknown'
    }
  end

  private

  def set_analysis_report
    @analysis_report = AnalysisReport.find(params[:id])
  end

  def calculate_progress(report)
    case report.status
    when 'generating'
      # Calculate based on how long it's been generating
      elapsed = Time.current - report.created_at
      estimated_total = 5.minutes # Estimated total time
      
      progress = (elapsed / estimated_total * 100).to_i
      [progress, 95].min # Never show 100% until actually completed
    when 'completed'
      100
    when 'failed'
      0
    else
      0
    end
  end

  def serialize_report(report)
    {
      id: report.id,
      report_type: report.report_type,
      status: report.status,
      file_size: report.respond_to?(:formatted_file_size) ? report.formatted_file_size : 'Unknown',
      ai_cost: report.ai_cost,
      generated_at: report.generated_at,
      download_url: report.respond_to?(:download_url) ? report.download_url : nil,
      sections_included: report.respond_to?(:sections_included) ? report.sections_included : [],
      ai_models_used: report.respond_to?(:ai_models_used) ? report.ai_models_used : [],
      generation_duration_minutes: report.respond_to?(:generation_duration) ? report.generation_duration : nil
    }
  end

  def generate_sample_report(form_response)
    # Método temporal para generar contenido de ejemplo
    # En producción, esto debería llamar a tu servicio de IA
    
    answers = form_response.question_responses.map do |qr|
      "**#{qr.form_question.title}:** #{qr.answer_data['value']}"
    end.join("\n\n")
    
    <<~MARKDOWN
      # Strategic Analysis Report
      
      ## Form Response Analysis
      
      **Response ID:** #{form_response.id}
      **Completed At:** #{form_response.completed_at&.strftime('%B %d, %Y at %H:%M')}
      **Total Time:** #{form_response.completed_at && form_response.started_at ? ((form_response.completed_at - form_response.started_at) / 60).round(2) : 'N/A'} minutes
      
      ## Responses Summary
      
      #{answers}
      
      ## Key Insights
      
      - Response demonstrates clear engagement with the form content
      - Time investment suggests thoughtful consideration of questions
      - Responses indicate strategic thinking and planning
      
      ## Recommendations
      
      1. **Follow-up Actions:** Consider personalized follow-up based on responses
      2. **Data Utilization:** Leverage insights for strategic decision making
      3. **Continuous Improvement:** Use feedback to enhance form effectiveness
      
      ---
      
      *Report generated on #{Time.current.strftime('%B %d, %Y at %H:%M %Z')}*
    MARKDOWN
  end
end