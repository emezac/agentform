# frozen_string_literal: true

module Forms
  # Background job responsible for AI-powered analysis of individual question responses
  # This job is triggered when a question response is created or updated and requires AI analysis
  class ResponseAnalysisJob < ApplicationJob
    queue_as :ai_processing
    
    # Retry on specific errors that might be temporary
    retry_on StandardError, wait: :polynomially_longer, attempts: 2
    
    # Discard if question response is not found or invalid
    discard_on ActiveRecord::RecordNotFound, ArgumentError
    
    def perform(question_response_id)
      log_progress("Starting response analysis for question response #{question_response_id}")
      
      # Find the question response
      question_response = find_record(QuestionResponse, question_response_id)
      form_response = question_response.form_response
      question = question_response.form_question
      
      # Validate prerequisites for AI analysis
      validate_analysis_prerequisites!(question_response, question, form_response)
      
      # Execute AI analysis workflow
      analysis_result = execute_ai_analysis(question_response)
      
      # Update question response with analysis results
      update_question_response_with_analysis(question_response, analysis_result) if analysis_result[:success]
      
      # Generate dynamic follow-up if needed
      schedule_dynamic_question_generation(question_response, analysis_result) if should_generate_followup?(analysis_result)
      
      # Update aggregate form response analysis
      update_aggregate_analysis(form_response)
      
      # Log completion
      log_progress("Response analysis completed", {
        question_response_id: question_response.id,
        success: analysis_result[:success],
        generated_followup: analysis_result[:generate_followup]
      })
      
      analysis_result
    rescue StandardError => e
      handle_analysis_error(question_response_id, e)
    end
    
    private
    
    # Validate that the question response is ready for AI analysis
    def validate_analysis_prerequisites!(question_response, question, form_response)
      unless question.ai_enhanced?
        raise ArgumentError, "Question #{question.id} does not have AI enhancement enabled"
      end
      
      unless form_response.form.user.can_use_ai_features?
        raise ArgumentError, "User #{form_response.form.user.id} cannot use AI features"
      end
      
      unless question_response.answer_data.present?
        raise ArgumentError, "Question response #{question_response.id} has no answer data to analyze"
      end
      
      # Check if already analyzed recently
      if question_response.ai_analysis_results.present? && 
         question_response.updated_at > 5.minutes.ago
        Rails.logger.info "Question response #{question_response.id} was recently analyzed, skipping"
        return false
      end
      
      log_progress("Analysis prerequisites validated", {
        question_response_id: question_response.id,
        question_type: question.question_type,
        ai_enhanced: question.ai_enhanced?
      })
      
      true
    end
    
    # Execute AI analysis using the ResponseAgent
    def execute_ai_analysis(question_response)
      log_progress("Executing AI analysis for question response #{question_response.id}")
      
      begin
        # Use the ResponseAgent to analyze response quality
        agent = Forms::ResponseAgent.new
        result = agent.analyze_response_quality(question_response.form_response)
        
        if result.is_a?(Hash) && result[:error]
          log_progress("AI analysis failed", {
            question_response_id: question_response.id,
            error: result[:error_message]
          })
          
          return {
            success: false,
            error: result[:error_message],
            error_type: result[:error_type] || 'analysis_error'
          }
        end
        
        # Extract analysis data from the result
        analysis_data = extract_analysis_data(result, question_response)
        
        log_progress("AI analysis completed successfully", {
          question_response_id: question_response.id,
          confidence_score: analysis_data[:confidence_score],
          sentiment: analysis_data.dig(:ai_analysis, :sentiment)
        })
        
        {
          success: true,
          analysis_data: analysis_data,
          generate_followup: analysis_data[:generate_followup] || false,
          ai_cost: calculate_analysis_cost(question_response)
        }
      rescue StandardError => e
        Rails.logger.error "AI analysis execution failed: #{e.message}"
        
        {
          success: false,
          error: e.message,
          error_type: e.class.name
        }
      end
    end
    
    # Extract and structure analysis data from the agent result
    def extract_analysis_data(result, question_response)
      # Handle different result formats from the agent
      if result.respond_to?(:final_output)
        analysis_output = result.final_output
      elsif result.is_a?(Hash)
        analysis_output = result
      else
        analysis_output = { raw_result: result }
      end
      
      # Structure the analysis data
      {
        ai_analysis: {
          sentiment: extract_sentiment_data(analysis_output),
          quality: extract_quality_data(analysis_output),
          insights: extract_insights(analysis_output),
          flags: extract_flags(analysis_output),
          completeness: calculate_completeness_score(question_response, analysis_output)
        },
        confidence_score: analysis_output[:confidence_score] || calculate_confidence_score(analysis_output),
        completeness_score: analysis_output[:completeness_score] || calculate_completeness_score(question_response, analysis_output),
        generate_followup: analysis_output[:generate_followup] || should_generate_followup_from_analysis?(analysis_output),
        analyzed_at: Time.current.iso8601,
        analysis_version: 1
      }
    end
    
    # Extract sentiment analysis data
    def extract_sentiment_data(analysis_output)
      sentiment_data = analysis_output.dig(:ai_analysis, :sentiment) || analysis_output[:sentiment] || {}
      
      {
        label: sentiment_data[:label] || 'neutral',
        confidence: sentiment_data[:confidence] || 0.5,
        score: sentiment_data[:score] || 0.0,
        reasoning: sentiment_data[:reasoning] || ''
      }
    end
    
    # Extract quality analysis data
    def extract_quality_data(analysis_output)
      quality_data = analysis_output.dig(:ai_analysis, :quality) || analysis_output[:quality] || {}
      
      {
        completeness: quality_data[:completeness] || 0.5,
        relevance: quality_data[:relevance] || 0.5,
        clarity: quality_data[:clarity] || 0.5,
        overall_score: quality_data[:overall_score] || 0.5,
        issues: quality_data[:issues] || [],
        strengths: quality_data[:strengths] || []
      }
    end
    
    # Extract insights from the analysis
    def extract_insights(analysis_output)
      insights = analysis_output.dig(:ai_analysis, :insights) || analysis_output[:insights] || []
      
      # Ensure insights are properly formatted
      insights.map do |insight|
        if insight.is_a?(String)
          { text: insight, confidence: 0.7, category: 'general' }
        else
          insight
        end
      end
    end
    
    # Extract flags from the analysis
    def extract_flags(analysis_output)
      flags = analysis_output.dig(:ai_analysis, :flags) || analysis_output[:flags] || {}
      
      {
        needs_review: flags[:needs_review] || false,
        potential_spam: flags[:potential_spam] || false,
        incomplete_answer: flags[:incomplete_answer] || false,
        unusual_pattern: flags[:unusual_pattern] || false,
        high_quality: flags[:high_quality] || false
      }
    end
    
    # Calculate completeness score based on the response and analysis
    def calculate_completeness_score(question_response, analysis_output)
      base_score = analysis_output.dig(:completeness_score) || 0.5
      
      # Adjust based on answer length and type
      answer_data = question_response.answer_data
      question_type = question_response.form_question.question_type
      
      case question_type
      when 'text_short', 'text_long'
        text_length = answer_data.to_s.length
        length_score = [text_length / 100.0, 1.0].min
        base_score = (base_score + length_score) / 2.0
      when 'multiple_choice', 'single_choice'
        # Full score if valid choice is selected
        base_score = answer_data.present? ? 1.0 : 0.0
      end
      
      [base_score, 1.0].min.round(3)
    end
    
    # Calculate confidence score from analysis output
    def calculate_confidence_score(analysis_output)
      confidence_indicators = [
        analysis_output.dig(:sentiment, :confidence),
        analysis_output.dig(:quality, :overall_score),
        analysis_output.dig(:completeness_score)
      ].compact
      
      return 0.5 if confidence_indicators.empty?
      
      (confidence_indicators.sum / confidence_indicators.length).round(3)
    end
    
    # Determine if a follow-up question should be generated
    def should_generate_followup_from_analysis?(analysis_output)
      # Generate follow-up if:
      # 1. Analysis suggests it would be valuable
      # 2. Response shows engagement but needs clarification
      # 3. Quality score is moderate (not too low, not perfect)
      
      quality_score = analysis_output.dig(:quality, :overall_score) || 0.5
      sentiment_confidence = analysis_output.dig(:sentiment, :confidence) || 0.5
      
      # Sweet spot for follow-ups: engaged but could be more detailed
      quality_score.between?(0.4, 0.8) && sentiment_confidence > 0.6
    end
    
    # Calculate the AI cost for this analysis
    def calculate_analysis_cost(question_response)
      # Base cost for response analysis
      base_cost = 0.02
      
      # Additional cost based on answer complexity
      answer_length = question_response.answer_data.to_s.length
      complexity_multiplier = [1.0 + (answer_length / 1000.0), 3.0].min
      
      (base_cost * complexity_multiplier).round(4)
    end
    
    # Update the question response with analysis results
    def update_question_response_with_analysis(question_response, analysis_result)
      log_progress("Updating question response with analysis results")
      
      safe_db_operation do
        analysis_data = analysis_result[:analysis_data]
        
        question_response.update!(
          ai_analysis_results: analysis_data[:ai_analysis],
          ai_confidence_score: analysis_data[:confidence_score],
          ai_completeness_score: analysis_data[:completeness_score],
          ai_analysis_requested_at: Time.current
        )
        
        # Track AI usage
        user = question_response.form_response.form.user
        ai_cost = analysis_result[:ai_cost] || 0.02
        user.consume_ai_credit(ai_cost) if user.respond_to?(:consume_ai_credit)
        
        log_progress("Question response updated successfully", {
          question_response_id: question_response.id,
          confidence_score: analysis_data[:confidence_score],
          ai_cost: ai_cost
        })
      end
    rescue StandardError => e
      Rails.logger.error "Failed to update question response #{question_response.id}: #{e.message}"
      raise e
    end
    
    # Schedule dynamic question generation if needed
    def schedule_dynamic_question_generation(question_response, analysis_result)
      return unless analysis_result[:generate_followup]
      
      question = question_response.form_question
      form_response = question_response.form_response
      
      # Check if we've already generated enough follow-ups for this question
      existing_count = form_response.dynamic_questions
                                   .where(generated_from_question: question)
                                   .count
      
      max_followups = question.ai_configuration.dig('max_followups') || 2
      return if existing_count >= max_followups
      
      log_progress("Scheduling dynamic question generation", {
        form_response_id: form_response.id,
        source_question_id: question.id,
        existing_followups: existing_count
      })
      
      # Schedule the dynamic question generation job
      Forms::DynamicQuestionGenerationJob.perform_later(
        form_response.id,
        question.id
      )
    end
    
    # Check if follow-up should be generated based on analysis result
    def should_generate_followup?(analysis_result)
      return false unless analysis_result[:success]
      return false unless analysis_result[:generate_followup]
      
      # Additional checks can be added here
      true
    end
    
    # Update aggregate analysis for the entire form response
    def update_aggregate_analysis(form_response)
      log_progress("Updating aggregate analysis for form response #{form_response.id}")
      
      safe_db_operation do
        aggregate_data = aggregate_response_analysis(form_response)
        
        form_response.update!(
          ai_analysis_results: aggregate_data,
          ai_analysis_updated_at: Time.current
        )
        
        log_progress("Aggregate analysis updated", {
          form_response_id: form_response.id,
          overall_sentiment: aggregate_data[:overall_sentiment],
          overall_quality: aggregate_data[:overall_quality]
        })
      end
    rescue StandardError => e
      Rails.logger.error "Failed to update aggregate analysis for form response #{form_response.id}: #{e.message}"
      # Don't re-raise as this is not critical
    end
    
    # Aggregate analysis from all question responses in the form response
    def aggregate_response_analysis(form_response)
      analyses = form_response.question_responses
                             .where.not(ai_analysis_results: [nil, {}])
                             .pluck(:ai_analysis_results)
      
      return default_aggregate_analysis if analyses.empty?
      
      # Aggregate sentiment scores
      sentiments = analyses.map { |a| a.dig('sentiment', 'confidence') }.compact
      avg_sentiment = sentiments.any? ? sentiments.sum / sentiments.size : 0.5
      
      # Aggregate quality scores  
      quality_scores = analyses.map { |a| a.dig('quality', 'overall_score') }.compact
      avg_quality = quality_scores.any? ? quality_scores.sum / quality_scores.size : 0.5
      
      # Collect insights
      all_insights = analyses.flat_map { |a| a['insights'] || [] }
      
      # Collect flags
      all_flags = analyses.map { |a| a['flags'] || {} }.reduce({}) do |merged, flags|
        flags.each { |key, value| merged[key] = (merged[key] || false) || value }
        merged
      end
      
      {
        overall_sentiment: avg_sentiment.round(3),
        overall_quality: avg_quality.round(3),
        key_insights: all_insights.uniq.first(5),
        flags: all_flags,
        analysis_count: analyses.size,
        analyzed_at: Time.current.iso8601,
        completeness_distribution: calculate_completeness_distribution(analyses),
        sentiment_distribution: calculate_sentiment_distribution(analyses)
      }
    end
    
    # Default aggregate analysis structure
    def default_aggregate_analysis
      {
        overall_sentiment: 0.5,
        overall_quality: 0.5,
        key_insights: [],
        flags: {},
        analysis_count: 0,
        analyzed_at: Time.current.iso8601
      }
    end
    
    # Calculate distribution of completeness scores
    def calculate_completeness_distribution(analyses)
      completeness_scores = analyses.map { |a| a.dig('completeness') }.compact
      return {} if completeness_scores.empty?
      
      {
        high: completeness_scores.count { |score| score > 0.8 },
        medium: completeness_scores.count { |score| score.between?(0.4, 0.8) },
        low: completeness_scores.count { |score| score < 0.4 },
        average: (completeness_scores.sum / completeness_scores.size).round(3)
      }
    end
    
    # Calculate distribution of sentiment scores
    def calculate_sentiment_distribution(analyses)
      sentiments = analyses.map { |a| a.dig('sentiment', 'label') }.compact
      return {} if sentiments.empty?
      
      distribution = sentiments.tally
      total = sentiments.size
      
      distribution.transform_values { |count| (count.to_f / total * 100).round(1) }
    end
    
    # Handle analysis errors
    def handle_analysis_error(question_response_id, error)
      error_context = {
        question_response_id: question_response_id,
        job_id: job_id,
        error_message: error.message,
        error_type: error.class.name
      }
      
      Rails.logger.error "Response analysis failed for question response #{question_response_id}: #{error.message}"
      Rails.logger.error error.backtrace.join("\n") if Rails.env.development?
      
      # Try to update question response with error information if possible
      begin
        question_response = QuestionResponse.find_by(id: question_response_id)
        if question_response
          question_response.update!(
            ai_analysis_results: {
              error: {
                message: error.message,
                type: error.class.name,
                failed_at: Time.current.iso8601,
                job_id: job_id
              }
            }
          )
        end
      rescue StandardError => update_error
        Rails.logger.error "Failed to update question response with error information: #{update_error.message}"
      end
      
      # Track error in monitoring system
      if defined?(Sentry)
        Sentry.capture_exception(error, extra: error_context)
      end
      
      # Re-raise to trigger retry logic
      raise error
    end
  end
end