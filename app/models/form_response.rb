# frozen_string_literal: true

class FormResponse < ApplicationRecord
  # Associations
  belongs_to :form, counter_cache: :responses_count
  has_many :question_responses, dependent: :destroy
  has_many :dynamic_questions, dependent: :destroy
  has_many :analysis_reports, dependent: :destroy

  # Enums
  enum :status, { 
    in_progress: 'in_progress', 
    completed: 'completed', 
    abandoned: 'abandoned',
    paused: 'paused'
  }

  # Validations
  validates :session_id, presence: true
  validates :form, presence: true

  # Callbacks
  before_create :set_started_at
  before_save :update_last_activity
  after_update :sync_to_google_sheets, if: :saved_change_to_status?

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :this_week, -> { where(created_at: 1.week.ago..) }
  scope :this_month, -> { where(created_at: 1.month.ago..) }

  # Core Methods
  def progress_percentage
    return 0.0 if form.form_questions.count.zero?
    
    answered_count = question_responses.where.not(answer_data: {}).count
    total_count = form.form_questions.count
    
    (answered_count.to_f / total_count * 100).round(2)
  end

  def duration_minutes
    return 0 unless started_at
    
    end_time = completed_at || Time.current
    ((end_time - started_at) / 60.0).round(2)
  end

  def time_since_last_activity
    return 0 unless last_activity_at
    
    Time.current - last_activity_at
  end

  def is_stale?
    return false unless last_activity_at
    
    time_since_last_activity > 30.minutes
  end

  def answers_hash
    question_responses.includes(:form_question).each_with_object({}) do |qr, hash|
      question_title = qr.form_question.title
      hash[question_title] = qr.formatted_answer
    end
  end

  def get_answer(question_title_or_id)
    question = find_question(question_title_or_id)
    return nil unless question
    
    qr = question_responses.find_by(form_question: question)
    qr&.formatted_answer
  end

  def set_answer(question, answer_data)
    question_obj = question.is_a?(FormQuestion) ? question : find_question(question)
    return false unless question_obj
    
    qr = question_responses.find_or_initialize_by(form_question: question_obj)
    qr.answer_data = answer_data
    qr.save
  end

  def trigger_ai_analysis!
    return false unless form.ai_enabled?
    
    # Trigger AI analysis workflow
    # Forms::ResponseAnalysisJob.perform_later(self) if defined?(Forms::ResponseAnalysisJob)
    
    update(ai_analysis: ai_analysis.merge('requested_at' => Time.current.iso8601))
  end

  def ai_sentiment
    ai_analysis&.dig('sentiment') || 'neutral'
  end

  def ai_confidence
    ai_analysis&.dig('confidence_score') || 0.0
  end

  def ai_risk_indicators
    ai_analysis&.dig('risk_indicators') || []
  end

  def needs_human_review?
    return false unless ai_analysis.present?
    
    ai_confidence < 0.7 || ai_risk_indicators.any?
  end

  def calculate_quality_score!
    # Calculate quality based on completion, response times, and AI analysis
    completion_score = progress_percentage / 100.0
    time_score = duration_minutes < 30 ? 1.0 : [0.5, 30.0 / duration_minutes].max
    ai_score = ai_confidence
    
    quality = (completion_score * 0.5) + (time_score * 0.3) + (ai_score * 0.2)
    
    update(quality_score: quality.round(3))
    quality
  end

  def calculate_sentiment_score!
    return 0.0 unless ai_analysis.present?
    
    sentiment_mapping = {
      'very_positive' => 1.0,
      'positive' => 0.75,
      'neutral' => 0.5,
      'negative' => 0.25,
      'very_negative' => 0.0
    }
    
    score = sentiment_mapping[ai_sentiment] || 0.5
    update(sentiment_score: score)
    score
  end

  def mark_completed!(completion_data = {})
    return false unless can_be_completed?
    
    update!(
      status: :completed,
      completed_at: Time.current,
      completion_data: completion_data
    )
    
    # Trigger completion workflows
    # Forms::CompletionWorkflowJob.perform_later(self) if defined?(Forms::CompletionWorkflowJob)
    
    true
  end

  def mark_abandoned!(reason = nil)
    update!(
      status: :abandoned,
      abandoned_at: Time.current,
      abandonment_reason: reason
    )
  end

  def pause!(context = {})
    update!(
      status: :paused,
      paused_at: Time.current,
      metadata: metadata.merge('pause_context' => context)
    )
  end

  def resume!
    return false unless paused?
    
    update!(
      status: :in_progress,
      resumed_at: Time.current
    )
  end

  def workflow_context
    {
      form_id: form_id,
      response_id: id,
      session_id: session_id,
      status: status,
      progress: progress_percentage,
      current_question: current_question_position,
      answers: answers_hash,
      ai_analysis: ai_analysis,
      visitor_info: {
        ip_address: ip_address,
        user_agent: user_agent,
        referrer: referrer_url
      }
    }
  end

  def current_question_position
    answered_questions = question_responses.joins(:form_question)
                                          .where.not(answer_data: {})
                                          .order('form_questions.position')
    
    return 1 if answered_questions.empty?
    
    last_answered = answered_questions.last
    last_answered.form_question.position + 1
  end

  def can_be_completed?
    Rails.logger.info "    === CAN_BE_COMPLETED CHECK ==="
    
    # Obtiene todas las preguntas requeridas del formulario
    all_required_questions = form.form_questions.where(required: true).order(:position)
    Rails.logger.info "    Total required questions: #{all_required_questions.count}"
    
    # Filtra las preguntas requeridas que deben mostrarse según la lógica condicional actual
    visible_required_questions = all_required_questions.select do |question|
      should_show = question.should_show_for_response?(self)
      Rails.logger.info "    Required question '#{question.title}' should show: #{should_show}"
      should_show
    end
    
    Rails.logger.info "    Visible required questions: #{visible_required_questions.count}"
    
    visible_required_question_ids = visible_required_questions.map(&:id)
    
    # Cuenta cuántas de las preguntas requeridas visibles han sido respondidas (no saltadas)
    answered_visible_required_count = self.question_responses
                                        .where(form_question_id: visible_required_question_ids)
                                        .where(skipped: false)
                                        .where.not(answer_data: {})
                                        .count
    
    Rails.logger.info "    Answered visible required questions: #{answered_visible_required_count}"
    
    # Verifica si todas las preguntas requeridas visibles han sido respondidas
    can_complete = visible_required_question_ids.count == answered_visible_required_count
    
    Rails.logger.info "    Can be completed: #{can_complete}"
    Rails.logger.info "    === END CAN_BE_COMPLETED CHECK ==="
    
    can_complete
  end

  def next_question
    current_pos = current_question_position
    form.form_questions.where('position >= ?', current_pos).order(:position).first
  end

  def previous_question
    current_pos = current_question_position
    return nil if current_pos <= 1
    
    form.form_questions.where('position < ?', current_pos).order(:position).last
  end

  def response_summary
    {
      id: id,
      form_name: form.name,
      status: status,
      progress: progress_percentage,
      duration: duration_minutes,
      quality_score: quality_score,
      sentiment_score: sentiment_score,
      created_at: created_at,
      completed_at: completed_at
    }
  end

  # Method to get all responses including dynamic questions
  def complete_response_summary
    summary = {
      form_questions: answers_hash,
      dynamic_questions: dynamic_question_responses,
      metadata: {
        completed_at: completed_at,
        total_response_time: duration_minutes,
        form_name: form.name,
        response_id: id
      }
    }
    
    summary
  end

  # Get all dynamic question responses
  def dynamic_question_responses
    return {} unless dynamic_questions.any?
    
    dynamic_responses = {}
    
    dynamic_questions.answered.each do |dq|
      dynamic_responses[dq.title] = {
        answer: dq.answer_data['value'],
        answered_at: dq.answered_at || dq.answer_data['submitted_at'],
        trigger: dq.generation_context&.dig('trigger') || 'budget_analysis',
        question_type: dq.question_type,
        question_id: dq.id
      }
    end
    
    dynamic_responses
  end

  # Check if form response has dynamic questions answered
  def has_answered_dynamic_questions?
    dynamic_questions.where.not(answer_data: {}).exists?
  end

  # Get summary for thank you page
  def thank_you_summary
    {
      total_questions_answered: question_responses.count,
      dynamic_questions_answered: dynamic_questions.where.not(answer_data: {}).count,
      completion_time: duration_minutes,
      quality_score: calculate_response_quality_score
    }
  end

  def calculate_response_quality_score
    # Simple quality scoring based on completeness and engagement
    base_score = (question_responses.count.to_f / form.form_questions.count * 70).round
    
    # Bonus for dynamic question responses
    dynamic_bonus = dynamic_questions.where.not(answer_data: {}).count * 15
    
    # Ensure score doesn't exceed 100
    [[base_score + dynamic_bonus, 100].min, 0].max
  end

  # Método auxiliar para obtener preguntas no respondidas
  def unanswered_questions
    answered_question_ids = question_responses.pluck(:form_question_id)
    
    form.form_questions
        .where.not(id: answered_question_ids)
        .order(:position)
  end

  # Método auxiliar para obtener preguntas requeridas no respondidas
  def unanswered_required_questions
    answered_question_ids = question_responses.where(skipped: false)
                                            .where.not(answer_data: {})
                                            .pluck(:form_question_id)
    
    form.form_questions
        .where(required: true)
        .where.not(id: answered_question_ids)
        .select { |q| q.should_show_for_response?(self) }
  end

  private

  def set_started_at
    self.started_at = Time.current if started_at.blank?
  end

  def update_last_activity
    self.last_activity_at = Time.current
  end

  def sync_to_google_sheets
    return unless completed?
    return unless form.google_sheets_integration&.auto_sync?
    
    GoogleSheetsSyncJob.perform_later(form.id, 'sync_response', id)
  end

  def find_question(identifier)
    case identifier
    when String
      # Try to find by title first, then by ID
      form.form_questions.find_by(title: identifier) ||
        form.form_questions.find_by(id: identifier)
    when Integer, /\A\d+\z/
      form.form_questions.find_by(id: identifier.to_i)
    when FormQuestion
      identifier
    else
      nil
    end
  end
end