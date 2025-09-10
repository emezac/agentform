# frozen_string_literal: true

class AIRulesEngine
  def initialize(form, form_response, question, answer_data)
    @form = form
    @form_response = form_response
    @question = question
    @answer_data = answer_data
    @context = build_rich_context
  end

  def evaluate_and_execute
    results = []
    enabled_rule_sets = get_enabled_rule_sets.sort_by { |rs| rs['priority'] || 999 }
    
    enabled_rule_sets.each do |rule_set|
      if should_execute_rule_set?(rule_set) && conditions_match?(rule_set['conditions'])
        result = execute_rule_set_actions(rule_set)
        results << result
        
        # Break execution if necessary based on configuration
        break if rule_set.dig('execution_config', 'stop_on_success') && result[:success]
      end
    rescue StandardError => e
      Rails.logger.error "Error executing rule set #{rule_set['id']}: #{e.message}"
      results << { success: false, rule_set_id: rule_set['id'], error: e.message }
    end
    
    results
  end

  private

  def build_rich_context
    {
      form: {
        id: @form.id,
        name: @form.name,
        category: @form.category,
        description: @form.description,
        total_questions: @form.form_questions.count
      },
      
      response: {
        id: @form_response.id,
        completion_percentage: calculate_completion_percentage,
        duration_minutes: calculate_duration_minutes,
        quality_score: calculate_quality_score,
        previous_answers_summary: build_answers_summary
      },
      
      question: {
        id: @question.id,
        reference_id: @question.reference_id,
        title: @question.title,
        question_type: @question.question_type,
        position: @question.position
      },
      
      answer: {
        raw_value: @answer_data,
        text_content: extract_text_content,
        numeric_value: extract_numeric_value,
        sentiment_score: calculate_sentiment_score,
        response_time_ms: @answer_data.dig('response_time_ms')
      },
      
      user: {
        engagement_score: calculate_engagement_score,
        response_pattern: analyze_response_pattern
      }
    }
  end

  def calculate_completion_percentage
    total_questions = @form.form_questions.count
    answered_count = @form_response.question_responses.count
    return 0.0 if total_questions.zero?
    
    (answered_count.to_f / total_questions * 100).round(2)
  end

  def calculate_duration_minutes
    return 0.0 unless @form_response.started_at && @form_response.completed_at
    
    ((@form_response.completed_at - @form_response.started_at) / 60.0).round(2)
  end

  def calculate_quality_score
    # Basic quality score based on response characteristics
    score = 0.0
    
    # Check for empty responses
    empty_responses = @form_response.question_responses.select do |qr| 
      qr.answer_data['value'].blank? || qr.answer_data['value'].to_s.strip.empty?
    end
    
    score += (1.0 - (empty_responses.count.to_f / @form_response.question_responses.count)) * 50.0
    
    # Check response length for text questions
    text_responses = @form_response.question_responses.select { |qr| qr.form_question.question_type == 'text' }
    avg_length = text_responses.map { |qr| qr.answer_data['value'].to_s.length }.sum.to_f / text_responses.count
    score += [avg_length / 100.0, 1.0].min * 30.0
    
    # Check for reasonable response time
    if @answer_data.dig('response_time_ms')
      response_time = @answer_data['response_time_ms'].to_f
      if response_time > 1000 && response_time < 30000 # 1-30 seconds
        score += 20.0
      end
    end
    
    [score, 100.0].min
  end

  def build_answers_summary
    return '' if @form_response.question_responses.empty?
    
    summary_parts = @form_response.question_responses.limit(3).map do |qr|
      question = qr.form_question
      answer = qr.answer_data['value']
      "#{question.title}: #{answer.to_s.truncate(50)}"
    end
    
    summary_parts.join('; ')
  end

  def extract_text_content
    value = @answer_data['value']
    case value
    when String
      value.strip
    when Array
      value.join(', ')
    when Hash
      value.values.join(', ')
    else
      value.to_s
    end
  end

  def extract_numeric_value
    text = extract_text_content
    return 0.0 if text.blank?
    
    # Extract first number from text
    number_match = text.scan(/\d+(?:\.\d+)?/).first
    number_match ? number_match.to_f : 0.0
  end

  def calculate_sentiment_score
    text = extract_text_content
    return 0.0 if text.blank?
    
    # Simple sentiment analysis based on keywords
    positive_words = %w[good great excellent amazing wonderful fantastic love like positive happy satisfied]
    negative_words = %w[bad terrible awful horrible hate dislike negative unhappy frustrated angry disappointed]
    
    text_words = text.downcase.split
    positive_count = text_words.count { |word| positive_words.include?(word) }
    negative_count = text_words.count { |word| negative_words.include?(word) }
    
    total_words = text_words.length
    return 0.0 if total_words.zero?
    
    (positive_count - negative_count).to_f / total_words
  end

  def calculate_engagement_score
    score = 0.0
    
    # Response time indicates engagement
    if @answer_data.dig('response_time_ms')
      response_time = @answer_data['response_time_ms'].to_f
      if response_time > 2000 && response_time < 60000
        score += 30.0 # Reasonable response time
      end
    end
    
    # Answer length for text questions
    if @question.question_type == 'text'
      text_length = extract_text_content.length
      score += [text_length / 50.0, 40.0].min # Reward longer responses up to 2000 chars
    end
    
    # Form completion progress
    completion = calculate_completion_percentage
    score += (completion / 100.0) * 30.0
    
    [score, 100.0].min
  end

  def analyze_response_pattern
    return 'unknown' if @form_response.question_responses.empty?
    
    # Analyze response patterns based on timing and consistency
    response_times = @form_response.question_responses.map do |qr|
      qr.answer_data.dig('response_time_ms').to_i
    end.compact
    
    if response_times.empty?
      'unknown'
    elsif response_times.any? { |time| time < 500 } # Too fast
      'rushed'
    elsif response_times.any? { |time| time > 60000 } # Too slow
      'hesitant'
    else
      'consistent'
    end
  end

  def get_enabled_rule_sets
    return [] unless @form.ai_enhanced?
    
    config = @form.ai_configuration
    rule_sets = config.dig('rules_engine', 'rule_sets') || []
    rule_sets.select { |rs| rs['enabled'] == true }
  end

  def should_execute_rule_set?(rule_set)
    return true unless rule_set['execution_config']
    
    config = rule_set['execution_config']
    
    # Check cooldown period
    if config['cooldown_minutes']
      last_execution = get_last_execution_time(rule_set['id'])
      return false if last_execution && (Time.current - last_execution) < config['cooldown_minutes'].minutes
    end
    
    # Check max executions per response
    if config['max_executions_per_response']
      execution_count = get_execution_count(rule_set['id'])
      return false if execution_count >= config['max_executions_per_response']
    end
    
    true
  end

  def conditions_match?(conditions)
    operator = conditions['operator']
    rules = conditions['rules'] || []
    
    case operator
    when 'AND'
      rules.all? { |rule| evaluate_single_condition(rule) }
    when 'OR'  
      rules.any? { |rule| evaluate_single_condition(rule) }
    when 'NOT'
      !rules.any? { |rule| evaluate_single_condition(rule) }
    else
      false
    end
  end

  def evaluate_single_condition(rule)
    field_value = get_field_value(rule['field'])
    operator = rule['operator']
    expected_value = rule['value']
    
    case operator
    when 'equals'
      field_value == expected_value
    when 'not_equals'
      field_value != expected_value
    when 'greater_than'
      field_value.to_f > expected_value.to_f
    when 'less_than'
      field_value.to_f < expected_value.to_f
    when 'between'
      range = expected_value
      field_value.to_f >= range[0] && field_value.to_f <= range[1]
    when 'contains_keywords'
      text = field_value.to_s.downcase
      keywords = expected_value
      keywords.any? { |keyword| text.include?(keyword.downcase) }
    else
      false
    end
  rescue StandardError => e
    Rails.logger.error "Error evaluating condition: #{e.message}"
    false
  end

  def get_field_value(field_path)
    # Handle dot notation: "answer.numeric_value", "context.completion_percentage"
    parts = field_path.split('.')
    parts.reduce(@context) { |obj, part| obj&.dig(part) || obj&.[](part) }
  end

  def execute_rule_set_actions(rule_set)
    actions = rule_set['actions'] || []
    results = []
    
    actions.each do |action|
      case action['type']
      when 'generate_dynamic_question'
        result = execute_dynamic_question_generation(action['config'], rule_set)
        results << result
      when 'update_lead_score'
        result = execute_lead_score_update(action['config'])
        results << result
      when 'trigger_notification'
        result = execute_notification(action['config'])
        results << result
      end
    end
    
    update_execution_metrics(rule_set['id'])
    
    {
      success: results.any? { |r| r[:success] },
      rule_set_id: rule_set['id'],
      action_results: results
    }
  end

  def execute_dynamic_question_generation(config, rule_set)
    {
      type: 'generate_dynamic_question',
      success: true,
      config: config,
      rule_set_id: rule_set['id']
    }
  end

  def execute_lead_score_update(config)
    score_adjustment = config['score_adjustment'] || 0
    reason = config['reason'] || 'rule_based_adjustment'
    
    # Update lead score in form response
    current_score = @form_response.lead_score || 0
    new_score = [current_score + score_adjustment, 0].max
    
    @form_response.update!(lead_score: new_score)
    
    {
      type: 'update_lead_score',
      success: true,
      score_change: score_adjustment,
      new_score: new_score,
      reason: reason
    }
  end

  def execute_notification(config)
    notification_type = config['type']
    channels = config['channels'] || []
    template = config['template']
    
    channels.each do |channel|
      case channel
      when 'email'
        # Send email notification
        send_email_notification(notification_type, template)
      when 'slack'
        # Send Slack notification
        send_slack_notification(notification_type, template)
      end
    end
    
    {
      type: 'trigger_notification',
      success: true,
      channels: channels,
      notification_type: notification_type
    }
  end

  def send_email_notification(type, template)
    # Implementation would depend on your email system
    Rails.logger.info "Sending email notification: #{type} with template #{template}"
  end

  def send_slack_notification(type, template)
    # Implementation would depend on your Slack integration
    Rails.logger.info "Sending Slack notification: #{type} with template #{template}"
  end

  def get_last_execution_time(rule_set_id)
    key = "rule_last_execution:#{rule_set_id}:#{@form_response.id}"
    timestamp = Rails.cache.read(key)
    timestamp ? Time.at(timestamp) : nil
  end

  def get_execution_count(rule_set_id)
    key = "rule_execution_count:#{rule_set_id}:#{@form_response.id}"
    Rails.cache.read(key) || 0
  end

  def update_execution_metrics(rule_set_id)
    # Update last execution time
    last_exec_key = "rule_last_execution:#{rule_set_id}:#{@form_response.id}"
    Rails.cache.write(last_exec_key, Time.current.to_i, expires_in: 1.hour)
    
    # Update execution count
    count_key = "rule_execution_count:#{rule_set_id}:#{@form_response.id}"
    current_count = Rails.cache.read(count_key) || 0
    Rails.cache.write(count_key, current_count + 1, expires_in: 1.hour)
  end
end