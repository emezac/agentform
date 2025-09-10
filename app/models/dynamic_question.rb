# frozen_string_literal: true

class DynamicQuestion < ApplicationRecord
  # Associations
  belongs_to :form_response
  belongs_to :generated_from_question, class_name: 'FormQuestion', optional: true

  # Validations
  validates :title, presence: true
  validates :question_type, inclusion: { in: FormQuestion::QUESTION_TYPES }

  # Aliases for backward compatibility
  alias_attribute :configuration, :question_config

  # Scopes
  scope :answered, -> { where.not(answer_data: {}) }
  scope :unanswered, -> { where(answer_data: {}) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_confidence, ->(min_confidence) { where('ai_confidence >= ?', min_confidence) }

  # Callbacks
  before_save :ensure_configuration_defaults

  # Core Methods
  def question_type_handler
    # Reuse the same handler system as FormQuestion
    "QuestionTypes::#{question_type.classify}".constantize.new(self)
  rescue NameError
    QuestionTypes::Base.new(self)
  end

  def validate_answer(answer)
    question_type_handler.validate_answer(answer)
  end

  def process_answer(raw_answer)
    processed = question_type_handler.process_answer(raw_answer)
    
    # Store the processed answer
    self.answer_data = {
      'raw_answer' => raw_answer,
      'processed_answer' => processed,
      'answered_at' => Time.current.iso8601,
      'question_type' => question_type
    }
    
    processed
  end

  def render_component
    question_type_handler.render_component
  end

  def generation_reasoning
    generation_context&.dig('reasoning') || 'No reasoning provided'
  end

  def was_answered?
    answer_data.present? && answer_data != {}
  end

  def formatted_answer
    return 'Not answered' unless was_answered?
    
    processed_answer = answer_data['processed_answer']
    
    case question_type
    when 'multiple_choice', 'checkbox'
      format_choice_answer(processed_answer)
    when 'rating', 'scale'
      format_rating_answer(processed_answer)
    when 'nps_score'
      format_nps_answer(processed_answer)
    when 'date'
      format_date_answer(processed_answer)
    when 'datetime'
      format_datetime_answer(processed_answer)
    when 'file_upload', 'image_upload'
      format_file_answer(processed_answer)
    else
      processed_answer.to_s
    end
  end

  def answer_text
    return '' unless was_answered?
    
    answer_data['processed_answer'].to_s
  end

  def generation_metadata
    {
      generated_from: generated_from_question&.title,
      generation_model: generation_model,
      ai_confidence: ai_confidence,
      generation_prompt: generation_prompt,
      context: generation_context,
      created_at: created_at
    }
  end

  def response_summary
    {
      id: id,
      title: title,
      question_type: question_type,
      answer: formatted_answer,
      was_answered: was_answered?,
      response_time: response_time_ms,
      ai_confidence: ai_confidence,
      generation_metadata: generation_metadata
    }
  end

  def similar_to_original?
    return false unless generated_from_question
    
    # Check if the dynamic question is similar to the original
    title_similarity = calculate_text_similarity(title, generated_from_question.title)
    type_match = question_type == generated_from_question.question_type
    
    title_similarity > 0.7 || type_match
  end

  def effectiveness_score
    # Calculate how effective this dynamic question was
    base_score = was_answered? ? 0.5 : 0.0
    
    # Add points for AI confidence
    confidence_score = (ai_confidence || 0.0) * 0.3
    
    # Add points for response time (faster is better, but not too fast)
    time_score = if response_time_ms.present?
      optimal_time = 5000.0 # 5 seconds
      if response_time_ms < 1000 # Too fast, might be careless
        0.1
      elsif response_time_ms <= optimal_time
        0.2
      elsif response_time_ms <= 30000 # Up to 30 seconds is reasonable
        0.15
      else
        0.05 # Too slow
      end
    else
      0.1
    end
    
    (base_score + confidence_score + time_score).round(3)
  end

  def should_generate_followup?
    return false unless was_answered?
    
    # Generate followup if:
    # 1. AI confidence is high enough
    # 2. Answer suggests more information could be gathered
    # 3. Original question was configured for followups
    
    high_confidence = (ai_confidence || 0.0) >= 0.7
    original_supports_followups = generated_from_question&.generates_followups? || false
    answer_suggests_followup = answer_suggests_more_info?
    
    high_confidence && (original_supports_followups || answer_suggests_followup)
  end

  def next_followup_context
    return {} unless should_generate_followup?
    
    {
      previous_question: title,
      previous_answer: formatted_answer,
      original_question: generated_from_question&.title,
      form_context: form_response.answers_hash,
      confidence_level: ai_confidence,
      suggested_direction: suggest_followup_direction
    }
  end

  private

  def ensure_configuration_defaults
    self.configuration ||= {}
    self.generation_context ||= {}
    
    # Set default configuration based on question type
    case question_type
    when 'text_short'
      self.configuration['max_length'] ||= 255
    when 'text_long'
      self.configuration['max_length'] ||= 5000
    when 'rating'
      self.configuration['min_value'] ||= 1
      self.configuration['max_value'] ||= 5
    when 'scale'
      self.configuration['min_value'] ||= 0
      self.configuration['max_value'] ||= 10
    end
  end

  def format_choice_answer(processed_answer)
    return '' if processed_answer.blank?
    
    choices = processed_answer.is_a?(Array) ? processed_answer : [processed_answer]
    choices.join(', ')
  end

  def format_rating_answer(processed_answer)
    max_value = configuration.dig('max_value') || 5
    "#{processed_answer}/#{max_value}"
  end

  def format_nps_answer(processed_answer)
    score = processed_answer.to_i
    category = case score
               when 0..6 then 'Detractor'
               when 7..8 then 'Passive'
               when 9..10 then 'Promoter'
               else 'Unknown'
               end
    "#{score} (#{category})"
  end

  def format_date_answer(processed_answer)
    Date.parse(processed_answer.to_s).strftime('%B %d, %Y')
  rescue
    processed_answer.to_s
  end

  def format_datetime_answer(processed_answer)
    Time.parse(processed_answer.to_s).strftime('%B %d, %Y at %I:%M %p')
  rescue
    processed_answer.to_s
  end

  def format_file_answer(processed_answer)
    return 'No files' if processed_answer.blank?
    
    files = processed_answer.is_a?(Array) ? processed_answer : [processed_answer]
    filenames = files.map { |f| f['filename'] || 'Unknown file' }
    "#{files.count} file(s): #{filenames.join(', ')}"
  end

  def calculate_text_similarity(text1, text2)
    # Simple similarity calculation based on common words
    return 0.0 if text1.blank? || text2.blank?
    
    words1 = text1.downcase.split(/\W+/).reject(&:blank?)
    words2 = text2.downcase.split(/\W+/).reject(&:blank?)
    
    return 0.0 if words1.empty? || words2.empty?
    
    common_words = words1 & words2
    total_unique_words = (words1 | words2).length
    
    common_words.length.to_f / total_unique_words
  end

  def answer_suggests_more_info?
    return false unless was_answered?
    
    answer = answer_text.downcase
    
    # Look for indicators that suggest more information could be gathered
    followup_indicators = [
      'because', 'since', 'due to', 'reason', 'explain', 'detail',
      'specifically', 'particularly', 'especially', 'mainly', 'primarily',
      'however', 'but', 'although', 'though', 'except', 'besides',
      'additionally', 'also', 'furthermore', 'moreover', 'plus'
    ]
    
    followup_indicators.any? { |indicator| answer.include?(indicator) }
  end

  def suggest_followup_direction
    return 'general' unless was_answered?
    
    answer = answer_text.downcase
    
    if answer.match?(/\b(why|reason|because|since)\b/)
      'reasoning'
    elsif answer.match?(/\b(how|method|process|way)\b/)
      'methodology'
    elsif answer.match?(/\b(when|time|date|schedule)\b/)
      'timing'
    elsif answer.match?(/\b(where|location|place)\b/)
      'location'
    elsif answer.match?(/\b(who|person|people|team)\b/)
      'people'
    elsif answer.match?(/\b(what|which|specific|detail)\b/)
      'specifics'
    else
      'elaboration'
    end
  end
end