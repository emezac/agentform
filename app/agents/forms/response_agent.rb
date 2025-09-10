# frozen_string_literal: true

module Forms
  # Agent responsible for processing form responses and managing response lifecycle
  # Handles response processing, quality analysis, insights generation, and integrations
  class ResponseAgent < ApplicationAgent
    
    # Supported task types for this agent
    SUPPORTED_TASKS = %w[
      process_form_response
      complete_form_response
      analyze_response_quality
      generate_response_insights
      trigger_integrations
      recover_abandoned_response
    ].freeze
    
    def initialize(context = {})
      super(context)
      @supported_tasks = SUPPORTED_TASKS
    end
    
    # Process a form response with AI analysis and workflow execution
    # @param form_response [FormResponse] The response being processed
    # @param question [FormQuestion] The question being answered
    # @param answer_data [Hash] The answer data from the user
    # @param metadata [Hash] Additional metadata about the response
    # @return [Hash] Success/error response with processing results
    def process_form_response(form_response, question, answer_data, metadata = {})
      validate_context(:user_id) if @context[:user_id]
      
      log_activity("process_form_response", { 
        form_response_id: form_response.id,
        question_id: question.id,
        has_answer_data: answer_data.present?
      })
      
      safe_db_operation do
        # Validate inputs
        unless valid_response_inputs?(form_response, question, answer_data)
          return error_response("Invalid response inputs", 'validation_error')
        end
        
        # Check if form is still accepting responses
        unless form_accepting_responses?(form_response.form)
          return error_response("Form is no longer accepting responses", 'form_closed_error')
        end
        
        # Execute response processing workflow
        workflow_result = execute_workflow(
          Forms::ResponseProcessingWorkflow,
          {
            form_response_id: form_response.id,
            question_id: question.id,
            answer_data: answer_data,
            metadata: metadata,
            processing_context: @context
          }
        )
        
        if workflow_result[:success]
          # Update response activity timestamp
          form_response.touch(:last_activity_at)
          
          # Track response processing
          track_response_processing(form_response, question)
          
          success_response({
            form_response_id: form_response.id,
            question_id: question.id,
            processing_result: workflow_result[:data],
            ai_analysis: workflow_result[:data][:ai_analysis],
            dynamic_questions: workflow_result[:data][:dynamic_questions],
            processed_at: Time.current
          })
        else
          error_response("Response processing failed: #{workflow_result[:error_message]}", 'processing_error')
        end
      end
    end
    
    # Complete a form response and trigger completion workflows
    # @param form_response [FormResponse] The response to complete
    # @return [Hash] Success/error response with completion results
    def complete_form_response(form_response)
      log_activity("complete_form_response", { form_response_id: form_response.id })
      
      # Validate form response ownership or access
      unless can_access_response?(form_response)
        return error_response("Not authorized to complete this response", 'authorization_error')
      end
      
      safe_db_operation do
        # Validate response is ready for completion
        validation_result = validate_response_for_completion(form_response)
        unless validation_result[:valid]
          return error_response(validation_result[:errors].join(', '), 'validation_error')
        end
        
        # Mark response as completed
        completion_data = {
          completed_at: Time.current,
          completion_duration: calculate_completion_duration(form_response),
          final_quality_score: calculate_final_quality_score(form_response)
        }
        
        form_response.mark_completed!(completion_data)
        
        # Execute completion workflow for integrations and analysis
        completion_result = execute_completion_workflow(form_response)
        
        # Update form statistics
        update_form_completion_stats(form_response.form)
        
        success_response({
          form_response_id: form_response.id,
          status: form_response.status,
          completion_data: completion_data,
          integrations_triggered: completion_result[:integrations_triggered],
          analysis_queued: completion_result[:analysis_queued],
          completed_at: Time.current
        })
      end
    end
    
    # Analyze response quality using AI and statistical methods
    # @param form_response [FormResponse] The response to analyze
    # @return [Hash] Quality analysis results and recommendations
    def analyze_response_quality(form_response)
      log_activity("analyze_response_quality", { form_response_id: form_response.id })
      
      # Validate access to response
      unless can_access_response?(form_response)
        return error_response("Not authorized to analyze this response", 'authorization_error')
      end
      
      # Check if response has enough data for analysis
      if form_response.question_responses.empty?
        return error_response("Response has no answers to analyze", 'insufficient_data')
      end
      
      # Check AI credits if AI analysis is requested
      estimated_cost = calculate_analysis_cost(form_response)
      if form_response.form.ai_enhanced? && !ai_budget_available?(@context, estimated_cost)
        return error_response("Insufficient AI credits for quality analysis", 'insufficient_credits')
      end
      
      begin
        # Perform quality analysis
        quality_metrics = calculate_quality_metrics(form_response)
        
        # AI-powered analysis if enabled
        ai_analysis = nil
        if form_response.form.ai_enhanced?
          ai_analysis = perform_ai_quality_analysis(form_response)
          track_ai_usage(@context, estimated_cost, 'response_quality_analysis')
        end
        
        # Generate quality insights
        insights = generate_quality_insights(quality_metrics, ai_analysis)
        
        # Update response with analysis results
        update_response_quality_data(form_response, quality_metrics, ai_analysis)
        
        success_response({
          form_response_id: form_response.id,
          quality_score: quality_metrics[:overall_score],
          quality_metrics: quality_metrics,
          ai_analysis: ai_analysis,
          insights: insights,
          recommendations: generate_quality_recommendations(quality_metrics),
          analyzed_at: Time.current
        })
      rescue StandardError => e
        logger.error "Quality analysis failed for response #{form_response.id}: #{e.message}"
        error_response("Quality analysis failed: #{e.message}", 'analysis_error')
      end
    end
    
    # Generate insights from form response data using AI
    # @param form_response [FormResponse] The response to generate insights for
    # @return [Hash] Generated insights and analysis
    def generate_response_insights(form_response)
      log_activity("generate_response_insights", { form_response_id: form_response.id })
      
      # Validate access to response
      unless can_access_response?(form_response)
        return error_response("Not authorized to generate insights for this response", 'authorization_error')
      end
      
      # Check if AI features are enabled
      unless form_response.form.ai_enhanced?
        return error_response("AI insights not enabled for this form", 'feature_disabled')
      end
      
      # Check AI credits availability
      estimated_cost = calculate_insights_cost(form_response)
      unless ai_budget_available?(@context, estimated_cost)
        return error_response("Insufficient AI credits for insight generation", 'insufficient_credits')
      end
      
      begin
        # Prepare response data for analysis
        response_context = prepare_response_context(form_response)
        
        # Generate AI insights
        insights_result = generate_ai_insights(form_response, response_context)
        
        if insights_result[:success]
          # Store insights in response
          store_response_insights(form_response, insights_result[:insights])
          
          # Track AI usage
          track_ai_usage(@context, estimated_cost, 'response_insights_generation')
          
          success_response({
            form_response_id: form_response.id,
            insights: insights_result[:insights],
            confidence_score: insights_result[:confidence],
            categories: insights_result[:categories],
            key_findings: insights_result[:key_findings],
            generated_at: Time.current
          })
        else
          error_response("Insight generation failed: #{insights_result[:error]}", 'insights_error')
        end
      rescue StandardError => e
        logger.error "Insight generation failed for response #{form_response.id}: #{e.message}"
        error_response("Insight generation failed: #{e.message}", 'insights_error')
      end
    end
    
    # Trigger integrations for a completed form response
    # @param form_response [FormResponse] The completed response
    # @return [Hash] Integration trigger results
    def trigger_integrations(form_response)
      log_activity("trigger_integrations", { 
        form_response_id: form_response.id,
        form_id: form_response.form.id
      })
      
      # Validate access to response
      unless can_access_response?(form_response)
        return error_response("Not authorized to trigger integrations for this response", 'authorization_error')
      end
      
      # Check if response is completed
      unless form_response.completed?
        return error_response("Response must be completed before triggering integrations", 'invalid_status')
      end
      
      begin
        form = form_response.form
        integration_settings = form.integration_settings || {}
        triggered_integrations = []
        failed_integrations = []
        
        # Process each enabled integration
        integration_settings.each do |integration_type, config|
          next unless config['enabled']
          
          integration_result = trigger_single_integration(
            integration_type, 
            config, 
            form_response
          )
          
          if integration_result[:success]
            triggered_integrations << {
              type: integration_type,
              status: 'triggered',
              job_id: integration_result[:job_id]
            }
          else
            failed_integrations << {
              type: integration_type,
              status: 'failed',
              error: integration_result[:error]
            }
          end
        end
        
        # Update response with integration status
        update_integration_status(form_response, triggered_integrations, failed_integrations)
        
        success_response({
          form_response_id: form_response.id,
          triggered_integrations: triggered_integrations,
          failed_integrations: failed_integrations,
          total_integrations: integration_settings.count,
          success_count: triggered_integrations.count,
          triggered_at: Time.current
        })
      rescue StandardError => e
        logger.error "Integration triggering failed for response #{form_response.id}: #{e.message}"
        error_response("Integration triggering failed: #{e.message}", 'integration_error')
      end
    end
    
    # Attempt to recover an abandoned form response
    # @param form_response [FormResponse] The abandoned response to recover
    # @return [Hash] Recovery attempt results
    def recover_abandoned_response(form_response)
      log_activity("recover_abandoned_response", { form_response_id: form_response.id })
      
      # Validate access to response
      unless can_access_response?(form_response)
        return error_response("Not authorized to recover this response", 'authorization_error')
      end
      
      # Check if response is actually abandoned
      unless form_response.abandoned? || form_response.is_stale?
        return error_response("Response is not abandoned", 'invalid_status')
      end
      
      safe_db_operation do
        # Analyze abandonment context
        abandonment_analysis = analyze_abandonment_context(form_response)
        
        # Generate recovery strategy
        recovery_strategy = generate_recovery_strategy(form_response, abandonment_analysis)
        
        # Execute recovery actions
        recovery_result = execute_recovery_actions(form_response, recovery_strategy)
        
        if recovery_result[:success]
          # Update response status
          form_response.resume!
          
          success_response({
            form_response_id: form_response.id,
            recovery_strategy: recovery_strategy,
            actions_taken: recovery_result[:actions_taken],
            abandonment_analysis: abandonment_analysis,
            recovery_probability: recovery_result[:recovery_probability],
            recovered_at: Time.current
          })
        else
          error_response("Recovery failed: #{recovery_result[:error]}", 'recovery_error')
        end
      end
    end
    
    # Enrich response data with external company information
    # @param form_response [FormResponse] The response to enrich
    # @param email [String] Email address to extract domain from
    # @return [Hash] Success/error response with enrichment results
    def enrich_response(form_response, email)
      log_activity("enrich_response", { 
        form_response_id: form_response.id,
        email: email
      })
      
      # Validate inputs
      unless form_response.is_a?(FormResponse) && email.present?
        return error_response("Invalid response or email", 'validation_error')
      end
      
      # Check if form has AI enhancement enabled
      unless form_response.form.ai_enhanced?
        return error_response("AI enrichment not enabled for this form", 'feature_disabled')
      end
      
      # Check authorization
      unless can_access_response?(form_response)
        return error_response("Not authorized to enrich this response", 'authorization_error')
      end
      
      # Check if already enriched
      if form_response.enrichment_data.present?
        return success_response({
          form_response_id: form_response.id,
          status: 'already_enriched',
          enrichment_data: form_response.enrichment_data,
          enriched_at: form_response.enriched_at
        })
      end
      
      safe_db_operation do
        # Queue enrichment job
        job_id = Forms::DataEnrichmentJob.perform_async(form_response.id, email)
        
        success_response({
          form_response_id: form_response.id,
          status: 'enrichment_queued',
          job_id: job_id,
          queued_at: Time.current
        })
      end
    end

    # Get list of supported tasks
    def supported_tasks
      SUPPORTED_TASKS + ['enrich_response']
    end
    
    private
    
    # Validate response processing inputs
    def valid_response_inputs?(form_response, question, answer_data)
      return false unless form_response.is_a?(FormResponse)
      return false unless question.is_a?(FormQuestion)
      return false unless answer_data.is_a?(Hash)
      return false unless question.form_id == form_response.form_id
      
      true
    end
    
    # Check if form is still accepting responses
    def form_accepting_responses?(form)
      form.published? && !form.archived?
    end
    
    # Check if current context can access the response
    def can_access_response?(form_response)
      # Public access for response submission
      return true if @context[:public_access]
      
      # Owner access
      return true if current_user && owns_resource?(form_response.form)
      
      # Session-based access for the responder
      return true if @context[:session_id] == form_response.session_id
      
      false
    end
    
    # Validate response is ready for completion
    def validate_response_for_completion(form_response)
      errors = []
      
      # Check if already completed
      errors << "Response is already completed" if form_response.completed?
      
      # Check required questions are answered
      required_questions = form_response.form.form_questions.where(required: true)
      answered_question_ids = form_response.question_responses.pluck(:form_question_id)
      
      missing_required = required_questions.where.not(id: answered_question_ids)
      if missing_required.exists?
        errors << "Required questions not answered: #{missing_required.pluck(:title).join(', ')}"
      end
      
      {
        valid: errors.empty?,
        errors: errors
      }
    end
    
    # Calculate completion duration in seconds
    def calculate_completion_duration(form_response)
      return 0 unless form_response.started_at
      
      Time.current - form_response.started_at
    end
    
    # Calculate final quality score for response
    def calculate_final_quality_score(form_response)
      # Base score from completeness
      completeness_score = (form_response.question_responses.count.to_f / 
                           form_response.form.form_questions.count) * 100
      
      # Adjust for response quality metrics
      quality_adjustments = 0
      
      form_response.question_responses.each do |qr|
        # Add points for detailed responses
        if (qr.answer_text&.length || 0) > 50
          quality_adjustments += 5
        end
        
        # Subtract points for very short responses to open questions
        if qr.form_question.question_type.in?(['text_long']) && (qr.answer_text&.length || 0) < 10
          quality_adjustments -= 10
        end
      end
      
      # Ensure score is between 0 and 100
      [[completeness_score + quality_adjustments, 0].max, 100].min
    end
    
    # Execute completion workflow
    def execute_completion_workflow(form_response)
      # Queue completion job for async processing
      job_id = Forms::CompletionWorkflowJob.perform_async(form_response.id)
      
      {
        integrations_triggered: true,
        analysis_queued: true,
        job_id: job_id
      }
    rescue StandardError => e
      logger.error "Failed to queue completion workflow: #{e.message}"
      {
        integrations_triggered: false,
        analysis_queued: false,
        error: e.message
      }
    end
    
    # Update form completion statistics
    def update_form_completion_stats(form)
      form.increment!(:completions_count)
      form.update!(last_response_at: Time.current)
    end
    
    # Calculate cost for response analysis
    def calculate_analysis_cost(form_response)
      base_cost = 0.02
      question_count_cost = form_response.question_responses.count * 0.005
      
      base_cost + question_count_cost
    end
    
    # Calculate quality metrics for response
    def calculate_quality_metrics(form_response)
      metrics = {
        completeness_score: calculate_completeness_score(form_response),
        response_time_score: calculate_response_time_score(form_response),
        consistency_score: calculate_consistency_score(form_response),
        engagement_score: calculate_engagement_score(form_response)
      }
      
      # Calculate overall score as weighted average
      metrics[:overall_score] = (
        metrics[:completeness_score] * 0.4 +
        metrics[:response_time_score] * 0.2 +
        metrics[:consistency_score] * 0.2 +
        metrics[:engagement_score] * 0.2
      ).round(2)
      
      metrics
    end
    
    # Perform AI-powered quality analysis
    def perform_ai_quality_analysis(form_response)
      # This would integrate with an AI analysis workflow
      # For now, return a structured placeholder
      {
        sentiment: 'positive',
        confidence: 0.85,
        key_themes: ['satisfaction', 'engagement'],
        quality_indicators: {
          coherence: 0.9,
          relevance: 0.8,
          completeness: 0.95
        },
        flags: []
      }
    end
    
    # Generate quality insights from metrics and AI analysis
    def generate_quality_insights(quality_metrics, ai_analysis)
      insights = []
      
      # Completeness insights
      if quality_metrics[:completeness_score] < 70
        insights << {
          type: 'completeness',
          message: 'Response appears incomplete',
          severity: 'medium'
        }
      end
      
      # Response time insights
      if quality_metrics[:response_time_score] < 50
        insights << {
          type: 'response_time',
          message: 'Unusually fast responses detected',
          severity: 'low'
        }
      end
      
      # AI insights
      if ai_analysis && ai_analysis[:confidence] < 0.7
        insights << {
          type: 'ai_confidence',
          message: 'AI analysis confidence is low',
          severity: 'medium'
        }
      end
      
      insights
    end
    
    # Generate quality recommendations
    def generate_quality_recommendations(quality_metrics)
      recommendations = []
      
      if quality_metrics[:overall_score] < 70
        recommendations << "Consider following up with respondent for clarification"
      end
      
      if quality_metrics[:completeness_score] < 80
        recommendations << "Review form design to improve completion rates"
      end
      
      recommendations
    end
    
    # Update response with quality analysis data
    def update_response_quality_data(form_response, quality_metrics, ai_analysis)
      form_response.update!(
        quality_score: quality_metrics[:overall_score],
        ai_analysis_data: {
          quality_metrics: quality_metrics,
          ai_analysis: ai_analysis,
          analyzed_at: Time.current
        }
      )
    end
    
    # Calculate cost for insights generation
    def calculate_insights_cost(form_response)
      base_cost = 0.03
      complexity_cost = form_response.question_responses.count * 0.01
      
      base_cost + complexity_cost
    end
    
    # Prepare response context for AI analysis
    def prepare_response_context(form_response)
      {
        form_title: form_response.form.name,
        form_category: form_response.form.category,
        response_count: form_response.form.responses_count,
        questions_and_answers: form_response.question_responses.includes(:form_question).map do |qr|
          {
            question: qr.form_question.title,
            question_type: qr.form_question.question_type,
            answer: qr.formatted_answer
          }
        end
      }
    end
    
    # Generate AI insights for response
    def generate_ai_insights(form_response, context)
      # This would integrate with an AI insights workflow
      # For now, return a structured placeholder
      {
        success: true,
        insights: {
          summary: "Respondent shows high engagement with detailed answers",
          sentiment: "positive",
          key_points: ["Detailed feedback provided", "Clear preferences expressed"],
          recommendations: ["Follow up within 24 hours", "Prioritize for sales contact"]
        },
        confidence: 0.88,
        categories: ["high_quality", "sales_qualified"],
        key_findings: [
          "Strong interest in product features",
          "Budget authority indicated",
          "Timeline specified"
        ]
      }
    end
    
    # Store insights in response record
    def store_response_insights(form_response, insights)
      current_data = form_response.ai_analysis_data || {}
      current_data[:insights] = insights
      current_data[:insights_generated_at] = Time.current
      
      form_response.update!(ai_analysis_data: current_data)
    end
    
    # Trigger a single integration
    def trigger_single_integration(integration_type, config, form_response)
      case integration_type.to_s
      when 'webhook'
        trigger_webhook_integration(config, form_response)
      when 'email'
        trigger_email_integration(config, form_response)
      when 'slack'
        trigger_slack_integration(config, form_response)
      when 'salesforce'
        trigger_salesforce_integration(config, form_response)
      else
        { success: false, error: "Unknown integration type: #{integration_type}" }
      end
    end
    
    # Trigger webhook integration
    def trigger_webhook_integration(config, form_response)
      job_id = Forms::IntegrationTriggerJob.perform_async(
        'webhook',
        config,
        form_response.id
      )
      
      { success: true, job_id: job_id }
    rescue StandardError => e
      { success: false, error: e.message }
    end
    
    # Trigger email integration
    def trigger_email_integration(config, form_response)
      job_id = Forms::IntegrationTriggerJob.perform_async(
        'email',
        config,
        form_response.id
      )
      
      { success: true, job_id: job_id }
    rescue StandardError => e
      { success: false, error: e.message }
    end
    
    # Trigger Slack integration
    def trigger_slack_integration(config, form_response)
      job_id = Forms::IntegrationTriggerJob.perform_async(
        'slack',
        config,
        form_response.id
      )
      
      { success: true, job_id: job_id }
    rescue StandardError => e
      { success: false, error: e.message }
    end
    
    # Trigger Salesforce integration
    def trigger_salesforce_integration(config, form_response)
      job_id = Forms::IntegrationTriggerJob.perform_async(
        'salesforce',
        config,
        form_response.id
      )
      
      { success: true, job_id: job_id }
    rescue StandardError => e
      { success: false, error: e.message }
    end
    
    # Update response with integration status
    def update_integration_status(form_response, triggered, failed)
      integration_data = {
        triggered_integrations: triggered,
        failed_integrations: failed,
        last_integration_attempt: Time.current
      }
      
      current_data = form_response.metadata || {}
      current_data[:integrations] = integration_data
      
      form_response.update!(metadata: current_data)
    end
    
    # Analyze abandonment context
    def analyze_abandonment_context(form_response)
      {
        abandonment_point: calculate_abandonment_point(form_response),
        time_spent: form_response.duration_minutes,
        questions_answered: form_response.question_responses.count,
        total_questions: form_response.form.form_questions.count,
        last_activity: form_response.last_activity_at,
        device_info: extract_device_info(form_response),
        abandonment_patterns: identify_abandonment_patterns(form_response)
      }
    end
    
    # Generate recovery strategy
    def generate_recovery_strategy(form_response, analysis)
      strategies = []
      
      # Email recovery if contact info available
      if has_contact_info?(form_response)
        strategies << {
          type: 'email_recovery',
          priority: 'high',
          timing: '2_hours'
        }
      end
      
      # Session recovery
      strategies << {
        type: 'session_recovery',
        priority: 'medium',
        timing: 'immediate'
      }
      
      # Simplified form version
      if analysis[:questions_answered] < 3
        strategies << {
          type: 'simplified_form',
          priority: 'low',
          timing: '24_hours'
        }
      end
      
      strategies
    end
    
    # Execute recovery actions
    def execute_recovery_actions(form_response, strategies)
      actions_taken = []
      
      strategies.each do |strategy|
        case strategy[:type]
        when 'email_recovery'
          if execute_email_recovery(form_response)
            actions_taken << 'email_sent'
          end
        when 'session_recovery'
          if execute_session_recovery(form_response)
            actions_taken << 'session_restored'
          end
        when 'simplified_form'
          if execute_simplified_form_recovery(form_response)
            actions_taken << 'simplified_form_created'
          end
        end
      end
      
      {
        success: actions_taken.any?,
        actions_taken: actions_taken,
        recovery_probability: calculate_recovery_probability(form_response, actions_taken)
      }
    end
    
    # Helper methods for quality scoring
    def calculate_completeness_score(form_response)
      total_questions = form_response.form.form_questions.count
      answered_questions = form_response.question_responses.count
      
      return 0 if total_questions.zero?
      
      (answered_questions.to_f / total_questions * 100).round(2)
    end
    
    def calculate_response_time_score(form_response)
      # Analyze response times for each question
      response_times = form_response.question_responses.pluck(:response_time_ms).compact
      return 50 if response_times.empty?
      
      avg_time = response_times.sum / response_times.count
      
      # Score based on reasonable response times (not too fast, not too slow)
      case avg_time
      when 0..1000 # Too fast (< 1 second)
        20
      when 1000..5000 # Good range (1-5 seconds)
        100
      when 5000..30000 # Acceptable (5-30 seconds)
        80
      else # Too slow (> 30 seconds)
        60
      end
    end
    
    def calculate_consistency_score(form_response)
      # Analyze consistency across similar questions
      # This is a simplified implementation
      80 # Placeholder score
    end
    
    def calculate_engagement_score(form_response)
      # Analyze engagement based on answer length and detail
      text_responses = form_response.question_responses.joins(:form_question)
                                  .where(form_questions: { question_type: ['text_short', 'text_long'] })
      
      return 50 if text_responses.empty?
      
      avg_length = text_responses.sum { |qr| qr.answer_text&.length || 0 } / text_responses.count
      
      # Score based on average response length
      case avg_length
      when 0..10
        30
      when 10..50
        70
      when 50..200
        100
      else
        90
      end
    end
    
    # Helper methods for abandonment recovery
    def calculate_abandonment_point(form_response)
      last_question = form_response.question_responses.order(:created_at).last
      return 0 unless last_question
      
      last_question.form_question.position
    end
    
    def extract_device_info(form_response)
      form_response.metadata&.dig('device_info') || {}
    end
    
    def identify_abandonment_patterns(form_response)
      # Analyze patterns that led to abandonment
      patterns = []
      
      # Check if abandoned on a specific question type
      last_question = form_response.question_responses.order(:created_at).last
      if last_question
        patterns << "abandoned_after_#{last_question.form_question.question_type}"
      end
      
      # Check timing patterns
      if form_response.duration_minutes < 1
        patterns << 'quick_abandonment'
      elsif form_response.duration_minutes > 30
        patterns << 'long_session_abandonment'
      end
      
      patterns
    end
    
    def has_contact_info?(form_response)
      # Check if response contains email or phone
      form_response.question_responses.joins(:form_question)
                  .where(form_questions: { question_type: ['email', 'phone'] })
                  .exists?
    end
    
    def execute_email_recovery(form_response)
      # Queue email recovery job
      # This would integrate with email service
      true
    end
    
    def execute_session_recovery(form_response)
      # Extend session or create recovery link
      # This would integrate with session management
      true
    end
    
    def execute_simplified_form_recovery(form_response)
      # Create a simplified version of the form
      # This would integrate with form duplication service
      true
    end
    
    def calculate_recovery_probability(form_response, actions_taken)
      base_probability = 0.15 # 15% base recovery rate
      
      # Increase probability based on actions taken
      actions_taken.each do |action|
        case action
        when 'email_sent'
          base_probability += 0.25
        when 'session_restored'
          base_probability += 0.10
        when 'simplified_form_created'
          base_probability += 0.15
        end
      end
      
      # Cap at 80% maximum probability
      [base_probability, 0.80].min
    end
    
    # Track response processing metrics
    def track_response_processing(form_response, question)
      logger.info "Response processed: form_response_id=#{form_response.id}, question_id=#{question.id}"
      
      # Could integrate with analytics service here
      # AnalyticsService.track_event('response_processed', {
      #   form_id: form_response.form_id,
      #   question_type: question.question_type
      # })
    end
  end
end