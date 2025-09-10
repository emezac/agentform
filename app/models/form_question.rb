# frozen_string_literal: true

class FormQuestion < ApplicationRecord
  # Associations
  belongs_to :form
  has_many :question_responses, dependent: :destroy
  has_many :dynamic_questions, foreign_key: 'generated_from_question_id', dependent: :destroy

  # Constants
  QUESTION_TYPES = %w[
    text_short text_long email phone url number
    multiple_choice single_choice checkbox
    rating scale slider yes_no boolean
    date datetime time
    file_upload image_upload
    address location payment signature
    nps_score matrix ranking drag_drop
  ].freeze

  # Enums
  enum :question_type, QUESTION_TYPES.index_with(&:itself)

  # Validations
  validates :title, presence: true, length: { maximum: 500 }
  validates :position, presence: true, numericality: { greater_than: 0 }
  validates :form, presence: true
  validates :question_type, inclusion: { in: QUESTION_TYPES }

  # Custom validations
  validate :validate_question_config
  validate :validate_conditional_logic

  # Aliases for backward compatibility
  alias_attribute :configuration, :question_config

  # Scopes
  scope :visible, -> { where(hidden: false) }
  scope :required_questions, -> { where(required: true) }
  scope :ai_enhanced, -> { where(ai_enhanced: true) }

  # Core Methods
  def question_type_handler
    # Simplified handler for now
    @question_type_handler ||= BasicQuestionHandler.new(self)
  end
  
  class BasicQuestionHandler
    def initialize(question)
      @question = question
    end
    
    def validate_answer(answer)
      [] # Return empty errors array for now
    end
    
    def process_answer(answer)
      answer # Return answer as-is
    end
    
    def render_component
      @question.question_type
    end
    
    def default_value
      nil
    end
  end

  def render_component
    question_type_handler.render_component
  end

  def validate_answer(answer)
    question_type_handler.validate_answer(answer)
  end

  def process_answer(raw_answer)
    question_type_handler.process_answer(raw_answer)
  end

  def default_value
    question_type_handler.default_value
  end

  def ai_enhanced?
    ai_enhanced && ai_config.present?
  end

  def ai_features
    return [] unless ai_enhanced?
    
    ai_config.fetch('features', [])
  end

  def position_rationale
    metadata&.dig('position_rationale')
  end

  def generation_data
    metadata&.dig('generation_data') || {}
  end

  def ai_confidence_threshold
    ai_config&.dig('confidence_threshold') || 0.7
  end

  def validation_enhancement_enabled?
    ai_features.include?('validation_enhancement')
  end

  def sentiment_analysis_enabled?
    ai_features.include?('sentiment_analysis')
  end

  def format_suggestions_enabled?
    ai_features.include?('format_suggestions')
  end

  def generates_followups?
    ai_features.include?('dynamic_followup')
  end

  def has_smart_validation?
    ai_features.include?('smart_validation')
  end

  def has_response_analysis?
    ai_features.include?('response_analysis')
  end

  def has_conditional_logic?
    conditional_enabled? && conditional_logic.present?
  end

  def conditional_rules
    return [] unless has_conditional_logic?
    
    conditional_logic.fetch('rules', [])
  end

def should_show_for_response?(form_response)
  return true unless has_conditional_logic?
  
  Rails.logger.info "    Evaluating conditional logic for question: #{title}"
  
  rules = conditional_rules
  return true if rules.empty?
  
  Rails.logger.info "    Rules to evaluate: #{rules.length}"
  
  # Verificar si alguna de las preguntas dependientes fue saltada
  dependency_check = check_dependency_chain(rules, form_response)
  if dependency_check[:has_skipped_dependencies]
    Rails.logger.info "    Question depends on skipped questions, handling gracefully"
    return handle_skipped_dependencies(dependency_check, rules, form_response)
  end
  
  # Evaluar todas las reglas - por defecto usamos AND logic
  logic_operator = conditional_logic.fetch('operator', 'and').downcase
  
  case logic_operator
  when 'and'
    # Todas las reglas deben ser verdaderas
    result = rules.all? { |rule| evaluate_condition(rule, form_response) }
  when 'or'
    # Al menos una regla debe ser verdadera
    result = rules.any? { |rule| evaluate_condition(rule, form_response) }
  else
    # Fallback a AND
    result = rules.all? { |rule| evaluate_condition(rule, form_response) }
  end
  
  Rails.logger.info "    Final conditional result: #{result}"
  result
end

  def choice_options
    return [] unless %w[multiple_choice single_choice checkbox].include?(question_type)
    
    question_config.fetch('options', [])
  end

  def rating_config
    return {} unless %w[rating scale nps_score].include?(question_type)
    
    {
      min: question_config.fetch('min_value', 1),
      max: question_config.fetch('max_value', 5),
      step: question_config.fetch('step', 1),
      labels: question_config.fetch('labels', {})
    }
  end

  def file_upload_config
    return {} unless %w[file_upload image_upload].include?(question_type)
    
    {
      max_size: question_config.fetch('max_size_mb', 10),
      allowed_types: question_config.fetch('allowed_types', []),
      multiple: question_config.fetch('multiple', false)
    }
  end

  def text_config
    return {} unless %w[text_short text_long].include?(question_type)
    
    {
      min_length: question_config.fetch('min_length', 0),
      max_length: question_config.fetch('max_length', question_type == 'text_short' ? 255 : 5000),
      placeholder: question_config.fetch('placeholder', ''),
      format: question_config.fetch('format', nil)
    }
  end

  def average_response_time_seconds
    question_responses.where.not(time_spent_seconds: 0).average(:time_spent_seconds)&.to_i || 0
  end

  def completion_rate
    return 0.0 if responses_count.zero?
    
    completed_responses = question_responses.where(skipped: false).count
    (completed_responses.to_f / responses_count * 100).round(2)
  end

  def analytics_summary(period = 30.days)
    {
      total_responses: question_responses.count,
      completion_rate: 100.0, # Placeholder
      avg_response_time: 30.0 # Placeholder
    }
  end

  def debug_conditional_setup(form_response = nil)
    puts "\n=== DEBUG: CONDITIONAL SETUP FOR #{title} ==="
    puts "Has conditional logic: #{has_conditional_logic?}"
    puts "Conditional enabled: #{conditional_enabled?}"
    puts "Conditional logic: #{conditional_logic}"
    puts "Conditional rules: #{conditional_rules}"
    
    if has_conditional_logic? && form_response
      puts "\n--- DEPENDENCY ANALYSIS ---"
      conditional_rules.each_with_index do |rule, index|
        puts "Rule #{index + 1}:"
        puts "  Question ID: #{rule['question_id']}"
        puts "  Operator: #{rule['operator']}"
        puts "  Expected Value: #{rule['value']}"
        
        # Find the dependent question
        dependent_question = FormQuestion.find_by(id: rule['question_id'])
        if dependent_question
          puts "  Dependent Question: #{dependent_question.title}"
          puts "  Dependent Question Type: #{dependent_question.question_type}"
          
          # Find the response
          response = form_response.question_responses.joins(:form_question)
                                .find_by(form_questions: { id: rule['question_id'] })
          
          if response
            puts "  Response exists: YES"
            puts "  Response skipped: #{response.skipped?}"
            puts "  Answer data: #{response.answer_data}"
            puts "  Answer text: #{response.answer_text}"
            actual_value = extract_actual_value(response)
            puts "  Extracted value: '#{actual_value}'"
            
            normalized_actual = normalize_value_for_comparison(actual_value, dependent_question.question_type)
            normalized_expected = normalize_value_for_comparison(rule['value'], dependent_question.question_type)
            puts "  Normalized actual: '#{normalized_actual}'"
            puts "  Normalized expected: '#{normalized_expected}'"
            
            result = evaluate_condition(rule, form_response)
            puts "  Evaluation result: #{result}"
          else
            puts "  Response exists: NO"
          end
        else
          puts "  Dependent Question: NOT FOUND"
        end
        puts ""
      end
    end
    puts "=== END DEBUG ===\n"
  end

  private

  def handle_skipped_dependencies(dependency_check, rules, form_response)
    Rails.logger.info "      Handling skipped dependencies: #{dependency_check[:skipped_dependencies]}"
    
    # Estrategia: Si una pregunta depende de preguntas que fueron saltadas,
    # evaluar solo las reglas que NO dependen de preguntas saltadas
    
    valid_rules = rules.reject do |rule|
      dependency_check[:skipped_dependencies].include?(rule['question_id'])
    end
    
    Rails.logger.info "      Valid rules after filtering: #{valid_rules.length}/#{rules.length}"
    
    if valid_rules.empty?
      # Si todas las dependencias fueron saltadas, la pregunta también se salta
      Rails.logger.info "      All dependencies were skipped, skipping this question"
      return false
    end
    
    # Evaluar solo las reglas válidas
    logic_operator = conditional_logic.fetch('operator', 'and').downcase
    
    case logic_operator
    when 'and'
      result = valid_rules.all? { |rule| evaluate_condition(rule, form_response) }
    when 'or'
      result = valid_rules.any? { |rule| evaluate_condition(rule, form_response) }
    else
      result = valid_rules.all? { |rule| evaluate_condition(rule, form_response) }
    end
    
    Rails.logger.info "      Result after filtering skipped dependencies: #{result}"
    result
  end

  def check_dependency_chain(rules, form_response)
    skipped_dependencies = []
    missing_dependencies = []
    
    rules.each do |rule|
      question_id = rule['question_id']
      response = form_response.question_responses.joins(:form_question)
                            .find_by(form_questions: { id: question_id })
      
      if response.nil?
        missing_dependencies << question_id
      elsif response.skipped?
        skipped_dependencies << question_id
      end
    end
    
    {
      has_skipped_dependencies: skipped_dependencies.any?,
      has_missing_dependencies: missing_dependencies.any?,
      skipped_dependencies: skipped_dependencies,
      missing_dependencies: missing_dependencies
    }
  end

  def clean_numeric_value(value_str)
    return '' if value_str.blank?
    
    # Remueve símbolos de moneda comunes y espacios
    cleaned = value_str.gsub(/[$€£¥,\s]/, '')
    
    # Verifica si es un número válido
    begin
      Float(cleaned)
      cleaned
    rescue ArgumentError
      # Si no es un número válido, devuelve el valor original
      value_str
    end
  end

  def handle_skipped_response(operator, expected_value)
    # Si la pregunta dependiente fue saltada explícitamente
    Rails.logger.info "        Handling skipped response with operator: #{operator}"
    
    case operator
    when 'is_empty'
      true  # Las preguntas saltadas se consideran vacías
    when 'is_not_empty'
      false # Las preguntas saltadas no tienen contenido
    when 'equals'
      # Solo es verdadero si esperamos explícitamente un valor que represente "saltado"
      expected_value.to_s.downcase.in?(['skipped', 'skip', 'empty', ''])
    when 'not_equals'
      # Es verdadero para cualquier valor que NO sea "saltado"
      !expected_value.to_s.downcase.in?(['skipped', 'skip', 'empty', ''])
    when 'contains', 'starts_with', 'ends_with', 'matches_pattern'
      false # Las preguntas saltadas no contienen nada
    when 'greater_than', 'less_than', 'greater_than_or_equal', 'less_than_or_equal'
      false # No se puede comparar numéricamente
    when 'in_list'
      # Solo verdadero si la lista incluye valores que representen "saltado"
      list_values = expected_value.is_a?(Array) ? expected_value : expected_value.to_s.split(',').map(&:strip)
      list_values.any? { |v| v.to_s.downcase.in?(['skipped', 'skip', 'empty', '']) }
    when 'not_in_list'
      # Verdadero si la lista NO incluye valores que representen "saltado"
      list_values = expected_value.is_a?(Array) ? expected_value : expected_value.to_s.split(',').map(&:strip)
      !list_values.any? { |v| v.to_s.downcase.in?(['skipped', 'skip', 'empty', '']) }
    else
      Rails.logger.warn "        Unknown operator for skipped response: #{operator}"
      false
    end
  end

  def handle_empty_response(operator, expected_value)
    # Si la pregunta tiene una respuesta registrada pero el valor está vacío
    Rails.logger.info "        Handling empty response with operator: #{operator}"
    
    case operator
    when 'is_empty'
      true
    when 'is_not_empty'
      false
    when 'equals'
      # Solo verdadero si esperamos explícitamente un valor vacío
      expected_value.blank? || expected_value.to_s.downcase.in?(['empty', '', 'null'])
    when 'not_equals'
      # Verdadero para cualquier valor no vacío
      expected_value.present? && !expected_value.to_s.downcase.in?(['empty', '', 'null'])
    when 'contains', 'starts_with', 'ends_with', 'matches_pattern'
      false # Los valores vacíos no contienen nada
    when 'greater_than', 'less_than', 'greater_than_or_equal', 'less_than_or_equal'
      false # No se puede comparar numéricamente con vacío
    when 'in_list'
      # Solo verdadero si la lista incluye valores vacíos
      list_values = expected_value.is_a?(Array) ? expected_value : expected_value.to_s.split(',').map(&:strip)
      list_values.any? { |v| v.blank? || v.to_s.downcase.in?(['empty', '', 'null']) }
    when 'not_in_list'
      # Verdadero si la lista NO incluye valores vacíos
      list_values = expected_value.is_a?(Array) ? expected_value : expected_value.to_s.split(',').map(&:strip)
      !list_values.any? { |v| v.blank? || v.to_s.downcase.in?(['empty', '', 'null']) }
    else
      Rails.logger.warn "        Unknown operator for empty response: #{operator}"
      false
    end
  end

  def extract_actual_value(response)
    # Prioridad en el orden de extracción:
    # 1. answer_data['value'] si existe y no está vacío
    # 2. answer_text si existe y no está vacío  
    # 3. answer_data como string si no está vacío
    
    if response.answer_data.present? && response.answer_data.is_a?(Hash)
      value = response.answer_data['value']
      return value if value.present? && value != '{}'
    end
    
    if response.answer_text.present?
      return response.answer_text
    end
    
    if response.answer_data.present? && response.answer_data != '{}'
      return response.answer_data.to_s
    end
    
    nil
  end

  def validate_question_config
    # Always validate choice questions even if config is blank
    case question_type
    when 'multiple_choice', 'single_choice', 'checkbox'
      validate_choice_config
    when 'rating', 'scale', 'nps_score'
      validate_rating_config if question_config.present?
    when 'file_upload', 'image_upload'
      validate_file_config if question_config.present?
    when 'text_short', 'text_long'
      validate_text_config if question_config.present?
    end
  end

  def validate_choice_config
    options = question_config['options']
    if options.blank? || !options.is_a?(Array) || options.empty?
      errors.add(:question_config, 'must include at least one option for choice questions')
    end
  end

  def validate_rating_config
    min_val = question_config['min_value']
    max_val = question_config['max_value']
    
    if min_val.present? && max_val.present? && min_val >= max_val
      errors.add(:question_config, 'min_value must be less than max_value')
    end
  end

  def validate_file_config
    max_size = question_config['max_size_mb']
    if max_size.present? && (max_size <= 0 || max_size > 100)
      errors.add(:question_config, 'max_size_mb must be between 1 and 100')
    end
  end

  def validate_text_config
    min_length = question_config['min_length']
    max_length = question_config['max_length']
    
    if min_length.present? && max_length.present? && min_length > max_length
      errors.add(:question_config, 'min_length must be less than or equal to max_length')
    end
  end

  def validate_conditional_logic
    return unless conditional_enabled? && conditional_logic.present?
    
    rules = conditional_logic['rules']
    return if rules.blank?
    
    unless rules.is_a?(Array)
      errors.add(:conditional_logic, 'rules must be an array')
      return
    end
    
    rules.each_with_index do |rule, index|
      validate_conditional_rule(rule, index)
    end
  end

  def validate_conditional_rule(rule, index)
    required_keys = %w[question_id operator value]
    missing_keys = required_keys - rule.keys
    
    if missing_keys.any?
      errors.add(:conditional_logic, "rule #{index + 1} is missing required keys: #{missing_keys.join(', ')}")
    end
  end

  def normalize_value_for_comparison(value, question_type)
    return '' if value.blank? || value == '{}' || value == {}
    
    case question_type
    when 'yes_no', 'boolean'
      # Manejo robusto de valores booleanos
      val = value.to_s.downcase.strip
      case val
      when 'true', '1', 'yes', 'y', 'sí', 'si', 'ok', 'okay'
        'true'
      when 'false', '0', 'no', 'n', 'not', 'nope'
        'false'
      when '{}'
        '' # Valor vacío
      else
        # Para valores como "Yes" (con mayúscula), normalizar a 'true'
        if val.in?(['yes', 'sí', 'si'])
          'true'
        elsif val.in?(['no'])
          'false'
        else
          val # Mantener valor original si no encaja en patrones conocidos
        end
      end
    when 'text_short', 'text_long', 'email', 'phone', 'url'
      # Para tipos de texto, normalizar case y whitespace
      value.to_s.downcase.strip
    when 'multiple_choice', 'single_choice', 'checkbox'
      # Para preguntas de elección, normalizar case
      value.to_s.downcase.strip
    when 'rating', 'scale', 'nps_score', 'number'
      # Para tipos numéricos, mantener como string pero limpiar
      clean_numeric_value(value.to_s.strip)
    when 'date', 'datetime', 'time'
      # Para tipos de fecha/hora, normalizar formato
      begin
        if value.to_s.strip.present?
          Date.parse(value.to_s).strftime('%Y-%m-%d')
        else
          ''
        end
      rescue
        value.to_s.strip
      end
    else
      # Normalización por defecto
      value.to_s.downcase.strip
    end
  end

  def should_use_case_insensitive?(question_type)
    # Use case-insensitive comparison for text-based question types
    # where case doesn't typically matter for logic
    case question_type
    when 'yes_no', 'boolean', 'text_short', 'text_long', 'multiple_choice', 'single_choice', 'checkbox'
      true
    when 'email', 'phone', 'url'
      # For these types, case might matter (especially URLs)
      false
    when 'rating', 'scale', 'nps_score', 'number', 'date', 'datetime', 'time'
      # Numeric/date types don't need case normalization
      false
    else
      # Default to case-insensitive for safety
      true
    end
  end

def evaluate_condition(rule, form_response)
  question_id = rule['question_id']
  operator = rule['operator']
  expected_value = rule['value']

  Rails.logger.info "      Evaluating rule: #{question_id} #{operator} #{expected_value}"

  # Encuentra la respuesta para la pregunta de la que dependemos
  response = form_response.question_responses.joins(:form_question)
                        .find_by(form_questions: { id: question_id })

  if response.nil?
    Rails.logger.info "      No response found for question #{question_id}"
    return handle_missing_response(operator)
  end

  # CLAVE: Verifica si la respuesta fue saltada
  if response.skipped?
    Rails.logger.info "      Response was skipped for question #{question_id}"
    return handle_skipped_response(operator, expected_value)
  end

  # Obtiene la pregunta de origen para saber su tipo
  source_question = FormQuestion.find_by(id: question_id)
  unless source_question
    Rails.logger.info "      Source question not found: #{question_id}"
    return false
  end

  # Extrae el valor real de la respuesta
  actual_value = extract_actual_value(response)

  # Verifica si el valor está realmente vacío/no respondido
  if actual_value.blank? || actual_value == '{}' || actual_value == {}
    Rails.logger.info "      Response exists but value is empty for question #{question_id}"
    return handle_empty_response(operator, expected_value)
  end

  Rails.logger.info "      Actual value: '#{actual_value}'"
  Rails.logger.info "      Expected value: '#{expected_value}'"
  Rails.logger.info "      Source question type: #{source_question.question_type}"

  # Normaliza ambos valores para comparación
  normalized_actual = normalize_value_for_comparison(actual_value, source_question.question_type)
  normalized_expected = normalize_value_for_comparison(expected_value, source_question.question_type)

  Rails.logger.info "      Normalized actual: '#{normalized_actual}'"
  Rails.logger.info "      Normalized expected: '#{normalized_expected}'"

  # Realiza la comparación
  result = perform_comparison(operator, normalized_actual, normalized_expected, actual_value, expected_value)
  
  Rails.logger.info "      Comparison result: #{result}"
  result
end
  
def handle_missing_response(operator)
  # Si la pregunta dependiente no ha sido respondida en absoluto
  Rails.logger.info "        Handling missing response with operator: #{operator}"
  
  case operator
  when 'is_empty'
    true  # Efectivamente está vacía
  when 'is_not_empty'
    false # No está llena
  when 'equals', 'not_equals', 'contains', 'starts_with', 'ends_with', 
       'greater_than', 'less_than', 'greater_than_or_equal', 'less_than_or_equal',
       'matches_pattern', 'in_list', 'not_in_list'
    false # No se puede evaluar sin respuesta
  else
    Rails.logger.warn "        Unknown operator for missing response: #{operator}"
    false
  end
end

  def perform_comparison(operator, normalized_actual, normalized_expected, actual_value, expected_value)
    case operator
    when 'equals', 'equals_ignore_case'
      normalized_actual == normalized_expected
    when 'not_equals', 'not_equals_ignore_case'
      normalized_actual != normalized_expected
    when 'contains', 'contains_ignore_case'
      normalized_actual.to_s.include?(normalized_expected.to_s)
    when 'starts_with', 'starts_with_ignore_case'
      normalized_actual.to_s.start_with?(normalized_expected.to_s)
    when 'ends_with', 'ends_with_ignore_case'
      normalized_actual.to_s.end_with?(normalized_expected.to_s)
    when 'greater_than'
      convert_to_numeric(actual_value) > convert_to_numeric(expected_value)
    when 'greater_than_or_equal'
      convert_to_numeric(actual_value) >= convert_to_numeric(expected_value)
    when 'less_than'
      convert_to_numeric(actual_value) < convert_to_numeric(expected_value)
    when 'less_than_or_equal'
      convert_to_numeric(actual_value) <= convert_to_numeric(expected_value)
    when 'is_empty'
      actual_value.blank?
    when 'is_not_empty'
      actual_value.present?
    when 'matches_pattern'
      begin
        regex = Regexp.new(expected_value.to_s, Regexp::IGNORECASE)
        actual_value.to_s.match?(regex)
      rescue RegexpError => e
        Rails.logger.error "Invalid regex pattern: #{expected_value} - #{e.message}"
        false
      end
    when 'in_list'
      # expected_value debe ser un array o string separado por comas
      list_values = expected_value.is_a?(Array) ? expected_value : expected_value.to_s.split(',').map(&:strip)
      list_values.map { |v| normalize_value_for_comparison(v, 'text_short') }
                .include?(normalized_actual)
    when 'not_in_list'
      # expected_value debe ser un array o string separado por comas
      list_values = expected_value.is_a?(Array) ? expected_value : expected_value.to_s.split(',').map(&:strip)
      !list_values.map { |v| normalize_value_for_comparison(v, 'text_short') }
                  .include?(normalized_actual)
    else
      Rails.logger.warn "Unknown operator: #{operator}"
      false
    end
  end

  def convert_to_numeric(value)
    return 0.0 if value.blank?
    
    # Remove common currency symbols and spaces
    cleaned_value = value.to_s.gsub(/[$€£¥,\s]/, '')
    
    # Try to convert to float
    Float(cleaned_value)
  rescue ArgumentError
    # If conversion fails, return 0
    0.0
  end

  def normalize_value_for_comparison(value, question_type)
    return '' if value.blank?
    
    case question_type
    when 'yes_no', 'boolean'
      # Normalize boolean values
      val = value.to_s.downcase.strip
      case val
      when 'true', '1', 'yes', 'y', 'sí', 'si'
        'true'
      when 'false', '0', 'no', 'n'
        'false'
      else
        val
      end
    when 'text_short', 'text_long', 'email', 'phone', 'url'
      # For text types, normalize case and whitespace
      value.to_s.downcase.strip
    when 'multiple_choice', 'single_choice', 'checkbox'
      # For choice questions, normalize case
      value.to_s.downcase.strip
    when 'rating', 'scale', 'nps_score', 'number'
      # For numeric types, keep as string but strip whitespace
      value.to_s.strip
    when 'date', 'datetime', 'time'
      # For date/time types, normalize format
      begin
        Date.parse(value.to_s).strftime('%Y-%m-%d')
      rescue
        value.to_s.strip
      end
    else
      # Default normalization
      value.to_s.downcase.strip
    end
  end
end