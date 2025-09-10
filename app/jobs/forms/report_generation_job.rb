class Forms::ReportGenerationJob < ApplicationJob
  queue_as :ai_processing

  def perform(form_response_id, analysis_report_id)
    form_response = FormResponse.find(form_response_id)
    analysis_report = AnalysisReport.find(analysis_report_id)

    Rails.logger.info "Starting report generation for FormResponse: #{form_response_id}"

    begin
      # Execute the ReportGenerationWorkflow
      workflow_result = Forms::ReportGenerationWorkflow.new.run({
        form_response_id: form_response_id
      })

      if workflow_result[:success]
        # Update the analysis report with results
        analysis_report.update!(
          status: 'completed',
          markdown_content: workflow_result[:markdown_content] || '',
          file_path: workflow_result[:file_path],
          file_size: workflow_result[:file_size],
          ai_cost: workflow_result[:ai_cost],
          generated_at: Time.current,
          metadata: workflow_result[:metadata] || {}
        )

        # Notify user via ActionCable if connected
        broadcast_completion(form_response, analysis_report)

        Rails.logger.info "Report generation completed successfully for #{form_response_id}"
      else
        handle_workflow_failure(analysis_report, workflow_result[:error])
      end

    rescue StandardError => e
      Rails.logger.error "Report generation failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      analysis_report.update!(
        status: 'failed',
        metadata: { 
          error: e.message,
          failed_at: Time.current.iso8601
        }
      )

      # Notify user of failure
      broadcast_failure(form_response, analysis_report, e.message)
    end
  end

  private

  def broadcast_completion(form_response, analysis_report)
    ActionCable.server.broadcast(
      "form_response_#{form_response.id}",
      {
        type: 'report_completed',
        report_id: analysis_report.id,
        download_url: analysis_report.download_url,
        file_size: analysis_report.formatted_file_size
      }
    )
  end

  def broadcast_failure(form_response, analysis_report, error_message)
    ActionCable.server.broadcast(
      "form_response_#{form_response.id}",
      {
        type: 'report_failed',
        report_id: analysis_report.id,
        error: error_message
      }
    )
  end

  def handle_workflow_failure(analysis_report, error)
    Rails.logger.error "Workflow failed: #{error}"
    
    analysis_report.update!(
      status: 'failed',
      metadata: {
        workflow_error: error,
        failed_at: Time.current.iso8601
      }
    )
  end
end