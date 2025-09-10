# frozen_string_literal: true

module Forms
  # Service for processing form question answers with validation, AI analysis, and integration triggers
  class AnswerProcessingService < ApplicationService
    attr_accessor :response, :question, :answer_data, :metadata
    
    attr_reader :question_response
    
    validates :response, presence: true
    validates :question, presence: true
    validates :answer_data, presence: true
    
    def initialize(response:, question:, answer_data:, metadata: {})
      @response = response
      @question = question
      @answer_data = answer_data
      @metadata = metadata || {}
      super()
    end
    
    def call
      return self unless valid?
      
      validate_service_inputs
      return self if failure?
      
      execute_in_transaction do
        process_answer
      end
      
      self
    end
    
    # Check if follow-up questions should be generated
    def should_generate_followup?
      return false unless question.generates_followups?
      return false unless @question_response&.ai_analysis&.dig('flags', 'needs_followup')
      
      # Check if we haven't already generated too many follow-ups
      existing_followups = response.dynamic_questions.where(generated_from_question: question).count
      existing_followups < max_followups_per_question
    end
    
    private
    
    def validate_service_inputs
      validate_response_question_relationship
      validate_answer_format
    end
    
    def validate_response_question_relationship
      if question.form_id != response.form_id
        add_error(:question, "does not belong to this form")
      end
    end
    
    def validate_answer_format
      validation_errors = question.validate_answer(answer_data)
      
      validation_errors.each do |error|
        add_error(:answer_data, error)
      end
    end
    
    def process_answer
      create_or_update_question_response
      update_response_metadata
      schedule_ai_analysis if should_trigger_ai_analysis?
      schedule_integrations if should_trigger_integrations?
      
      set_result(@question_response)
    end
    
    def create_or_update_question_response
      @question_response = response.question_responses.find_or_initialize_by(
        form_question: question
      )
      
      @question_response.assign_attributes(
        answer_data: question.process_answer(answer_data),
        raw_input: answer_data,
        response_time_ms: metadata[:response_time],
        revision_count: (@question_response.revision_count || 0) + 1,
        interaction_events: metadata[:interaction_events] || []
      )
      
      unless @question_response.save
        @question_response.errors.each do |error|
          add_error(:question_response, error.full_message)
        end
        raise ActiveRecord::Rollback
      end
    end
    
    def update_response_metadata
      response_metadata = response.metadata || {}
      
      updated_metadata = response_metadata.merge(
        last_question_id: question.id,
        total_revisions: response.question_responses.sum(:revision_count),
        last_activity_at: Time.current.iso8601
      )
      
      unless response.update(
        last_activity_at: Time.current,
        metadata: updated_metadata
      )
        response.errors.each do |error|
          add_error(:response, error.full_message)
        end
        raise ActiveRecord::Rollback
      end
    end
    
    def should_trigger_ai_analysis?
      question.ai_enhanced? && 
      response.form.user.can_use_ai_features? &&
      answer_data.present?
    end
    
    def should_trigger_integrations?
      response.form.integration_settings.present? &&
      response.form.integration_settings['trigger_on_answer'] == true
    end
    
    def schedule_ai_analysis
      Rails.logger.info "Scheduling AI analysis for question response #{@question_response.id}"
      Forms::ResponseAnalysisJob.perform_later(@question_response.id)
      
      set_context(:ai_analysis_scheduled, true)
    end
    
    def schedule_integrations
      Rails.logger.info "Scheduling integrations for response #{response.id}, question #{question.id}"
      Forms::IntegrationTriggerJob.perform_later(response.id, question.id)
      
      set_context(:integrations_scheduled, true)
    end
    
    def max_followups_per_question
      question.ai_config&.dig('max_followups') || 2
    end
  end
end