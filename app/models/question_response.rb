# frozen_string_literal: true

class QuestionResponse < ApplicationRecord
  # Associations
  belongs_to :form_response
  belongs_to :form_question

  # Validations
  validates :answer_data, presence: true, unless: :skipped?

  # Callbacks
  before_save :process_answer_data, :calculate_response_time
  after_create :trigger_ai_analysis, :update_question_analytics

  # Scopes
  scope :answered, -> { where.not(answer_data: {}).where(skipped: false) }
  scope :skipped, -> { where(skipped: true) }
  scope :recent, -> { order(created_at: :desc) }

  # Core Methods
  def processed_answer_data
    return {} if answer_data.blank?
    
    case form_question.question_type
    when 'multiple_choice', 'checkbox'
      process_choice_answer
    when 'rating', 'scale', 'nps_score'
      process_numeric_answer
    when 'file_upload', 'image_upload'
      process_file_answer
    when 'email'
      process_email_answer
    when 'phone'
      process_phone_answer
    else
      process_text_answer
    end
  end

  def raw_answer
    answer_data.is_a?(Hash) ? answer_data['value'] : answer_data
  end

  def formatted_answer
    processed_data = processed_answer_data
    
    case form_question.question_type
    when 'multiple_choice', 'checkbox'
      format_choice_answer(processed_data)
    when 'rating', 'scale'
      format_rating_answer(processed_data)
    when 'nps_score'
      format_nps_answer(processed_data)
    when 'date'
      format_date_answer(processed_data)
    when 'datetime'
      format_datetime_answer(processed_data)
    when 'file_upload', 'image_upload'
      format_file_answer(processed_data)
    else
      processed_data.to_s
    end
  end

  def answer_text
    formatted_answer.to_s
  end

  def trigger_ai_analysis!
    return false unless should_trigger_ai_analysis?
    
    # Trigger AI analysis workflow
    # Forms::ResponseAnalysisJob.perform_later(self) if defined?(Forms::ResponseAnalysisJob)
    
    update(ai_analysis_requested_at: Time.current)
  end

  def ai_sentiment
    ai_analysis_results&.dig('sentiment') || 'neutral'
  end

  def ai_confidence_score
    ai_analysis_results&.dig('confidence_score') || 0.0
  end

  def ai_insights
    ai_analysis_results&.dig('insights') || []
  end

  def needs_followup?
    return false unless ai_analysis_results.present?
    
    ai_insights.any? { |insight| insight['type'] == 'followup_suggested' } ||
      ai_confidence_score < 0.6
  end

  def answer_valid?
    validation_errors.empty?
  end

  def validation_errors
    errors = []
    
    # Check if answer meets question requirements
    if form_question.required? && answer_blank?
      errors << 'Answer is required'
    end
    
    # Type-specific validation
    case form_question.question_type
    when 'email'
      errors << 'Invalid email format' unless valid_email?
    when 'phone'
      errors << 'Invalid phone format' unless valid_phone?
    when 'number'
      errors << 'Must be a valid number' unless valid_number?
    when 'url'
      errors << 'Invalid URL format' unless valid_url?
    end
    
    # Custom validation rules
    validation_rules = form_question.validation_rules
    if validation_rules.present?
      errors.concat(validate_against_rules(validation_rules))
    end
    
    errors
  end

  def quality_indicators
    {
      completeness: calculate_completeness_score,
      response_time: response_time_category,
      ai_confidence: ai_confidence_score,
      validation_passed: answer_valid?,
      needs_review: needs_human_review?
    }
  end

  def response_time_category
    return 'unknown' if response_time_ms.nil?
    
    case response_time_ms
    when 0..2000
      'very_fast'
    when 2001..5000
      'fast'
    when 5001..15000
      'normal'
    when 15001..60000
      'slow'
    else
      'very_slow'
    end
  end

  def unusually_fast?
    response_time_ms.present? && response_time_ms < 1000
  end

  def unusually_slow?
    response_time_ms.present? && response_time_ms > 120000 # 2 minutes
  end

  def needs_human_review?
    unusually_fast? || 
      unusually_slow? || 
      ai_confidence_score < 0.5 || 
      !answer_valid?
  end

  def response_summary
    {
      question_title: form_question.title,
      question_type: form_question.question_type,
      answer: formatted_answer,
      response_time: response_time_ms,
      quality_score: calculate_completeness_score,
      ai_confidence: ai_confidence_score,
      needs_review: needs_human_review?
    }
  end

  private

  def process_answer_data
    return if answer_data.blank?
    
    # Ensure answer_data is properly structured
    if answer_data.is_a?(String)
      self.answer_data = { 'value' => answer_data }
    end
    
    # Add metadata
    self.answer_data['processed_at'] = Time.current.iso8601
    self.answer_data['question_type'] = form_question.question_type
  end

  def calculate_response_time
    return unless answer_data.present?
    
    # Calculate response time if timestamps are available
    if answer_data.is_a?(Hash) && answer_data['started_at'] && answer_data['completed_at']
      begin
        started = Time.parse(answer_data['started_at'])
        completed = Time.parse(answer_data['completed_at'])
        self.response_time_ms = ((completed - started) * 1000).to_i
      rescue ArgumentError
        # Invalid date format, skip response time calculation
        self.response_time_ms = nil
      end
    end
  end

  def trigger_ai_analysis
    return unless should_trigger_ai_analysis?
    
    # Queue AI analysis job
    trigger_ai_analysis!
  end

  def should_trigger_ai_analysis?
    form_question.ai_enhanced? && 
      !skipped? &&
      answer_data.present?
  end

  def update_question_analytics
    # Update question-level analytics
    Rails.cache.delete("question_analytics/#{form_question_id}")
    
    # Update form-level analytics
    Rails.cache.delete_matched("form/#{form_response.form_id}/*")
  end

  def calculate_completeness_score
    return 0.0 if answer_blank?
    
    score = 0.5 # Base score for having an answer
    
    # Add points for answer quality
    case form_question.question_type
    when 'text_short', 'text_long'
      text_length = answer_text.length
      if text_length >= 10
        score += 0.3
      elsif text_length >= 5
        score += 0.2
      end
    when 'multiple_choice', 'single_choice'
      score += 0.4 # Full points for choice questions
    when 'rating', 'scale'
      score += 0.4 # Full points for rating questions
    end
    
    # Bonus for AI confidence
    score += (ai_confidence_score * 0.1) if ai_confidence_score > 0
    
    [score, 1.0].min.round(3)
  end

  def answer_blank?
    return true if answer_data.blank?
    
    value = raw_answer
    value.blank? || (value.is_a?(Array) && value.empty?)
  end

  def process_choice_answer
    value = raw_answer
    return value if value.is_a?(Array)
    
    # Convert single choice to array for consistency
    value.present? ? [value] : []
  end

  def process_numeric_answer
    value = raw_answer
    value.is_a?(Numeric) ? value : value.to_f
  end

  def process_file_answer
    value = raw_answer
    return [] unless value.present?
    
    # Ensure file data is properly structured
    files = value.is_a?(Array) ? value : [value]
    files.map do |file|
      {
        filename: file['filename'],
        size: file['size'],
        content_type: file['content_type'],
        url: file['url']
      }
    end
  end

  def process_email_answer
    raw_answer.to_s.downcase.strip
  end

  def process_phone_answer
    # Remove non-numeric characters except +
    raw_answer.to_s.gsub(/[^\d+]/, '')
  end

  def process_text_answer
    raw_answer.to_s.strip
  end

  def format_choice_answer(processed_data)
    return '' if processed_data.blank?
    
    choices = processed_data.is_a?(Array) ? processed_data : [processed_data]
    choices.join(', ')
  end

  def format_rating_answer(processed_data)
    "#{processed_data}/#{form_question.rating_config[:max] || 5}"
  end

  def format_nps_answer(processed_data)
    score = processed_data.to_i
    category = case score
               when 0..6 then 'Detractor'
               when 7..8 then 'Passive'
               when 9..10 then 'Promoter'
               else 'Unknown'
               end
    "#{score} (#{category})"
  end

  def format_date_answer(processed_data)
    Date.parse(processed_data.to_s).strftime('%B %d, %Y')
  rescue
    processed_data.to_s
  end

  def format_datetime_answer(processed_data)
    Time.parse(processed_data.to_s).strftime('%B %d, %Y at %I:%M %p')
  rescue
    processed_data.to_s
  end

  def format_file_answer(processed_data)
    return 'No files' if processed_data.blank?
    
    files = processed_data.is_a?(Array) ? processed_data : [processed_data]
    filenames = files.map { |f| f[:filename] || f['filename'] || 'Unknown file' }
    "#{files.count} file(s): #{filenames.join(', ')}"
  end

  def valid_email?
    return true if answer_text.blank? # Let presence validation handle blank
    
    answer_text.match?(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
  end

  def valid_phone?
    return true if answer_text.blank?
    
    # Basic phone validation - adjust regex as needed
    answer_text.match?(/\A\+?[\d\s\-\(\)]{10,}\z/)
  end

  def valid_number?
    return true if answer_text.blank?
    
    answer_text.match?(/\A-?\d*\.?\d+\z/)
  end

  def valid_url?
    return true if answer_text.blank?
    
    answer_text.match?(/\Ahttps?:\/\/[^\s]+\z/)
  end

  def validate_against_rules(rules)
    errors = []
    
    rules.each do |rule, value|
      case rule
      when 'min_length'
        errors << "Answer must be at least #{value} characters" if answer_text.length < value
      when 'max_length'
        errors << "Answer must be no more than #{value} characters" if answer_text.length > value
      when 'min_value'
        errors << "Value must be at least #{value}" if raw_answer.to_f < value
      when 'max_value'
        errors << "Value must be no more than #{value}" if raw_answer.to_f > value
      end
    end
    
    errors
  end
end