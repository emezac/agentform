# frozen_string_literal: true

class AIConfigurationValidator
  SUPPORTED_OPERATORS = %w[equals not_equals greater_than less_than between contains_keywords].freeze
  SUPPORTED_ACTIONS = %w[generate_dynamic_question update_lead_score trigger_notification].freeze
  SUPPORTED_RULE_OPERATORS = %w[AND OR NOT].freeze
  
  def initialize(config)
    @config = config
    @errors = []
  end

  def validate
    validate_structure
    validate_rule_sets unless @errors.any?
    validate_ai_engine_config unless @errors.any?
    @errors.empty?
  end

  def errors
    @errors
  end

  private

  def validate_structure
    unless @config.is_a?(Hash)
      @errors << "Configuration must be a hash"
      return
    end

    unless @config['version'].present?
      @errors << "Configuration must include version field"
    end

    unless @config['enabled_features'].is_a?(Array)
      @errors << "enabled_features must be an array"
    end

    unless @config['rules_engine'].is_a?(Hash)
      @errors << "rules_engine must be a hash"
    end

    unless @config['ai_engine'].is_a?(Hash)
      @errors << "ai_engine must be a hash"
    end
  end

  def validate_rule_sets
    rule_sets = @config.dig('rules_engine', 'rule_sets') || []
    
    unless rule_sets.is_a?(Array)
      @errors << "rule_sets must be an array"
      return
    end

    rule_sets.each_with_index do |rule_set, index|
      validate_rule_set(rule_set, index)
    end
  end

  def validate_rule_set(rule_set, index)
    context = "rule_set[#{index}]"
    
    unless rule_set['id'].present?
      @errors << "#{context} missing required 'id' field"
    end

    unless rule_set['name'].present?
      @errors << "#{context} missing required 'name' field"
    end

    unless rule_set['priority'].is_a?(Integer)
      @errors << "#{context} priority must be an integer"
    end

    unless rule_set['enabled'].in?([true, false])
      @errors << "#{context} enabled must be true or false"
    end

    validate_conditions(rule_set['conditions'], context)
    validate_actions(rule_set['actions'] || [], context)
    validate_execution_config(rule_set['execution_config'], context)
  end

  def validate_conditions(conditions, context)
    unless conditions.is_a?(Hash)
      @errors << "#{context} conditions must be a hash"
      return
    end

    operator = conditions['operator']
    unless SUPPORTED_RULE_OPERATORS.include?(operator)
      @errors << "#{context} invalid operator '#{operator}'. Must be one of: #{SUPPORTED_RULE_OPERATORS.join(', ')}"
    end

    rules = conditions['rules'] || []
    unless rules.is_a?(Array)
      @errors << "#{context} rules must be an array"
      return
    end

    rules.each_with_index do |rule, rule_index|
      validate_single_rule(rule, "#{context}.rules[#{rule_index}]")
    end
  end

  def validate_single_rule(rule, context)
    unless rule['field'].present?
      @errors << "#{context} missing required 'field'"
    end

    operator = rule['operator']
    unless SUPPORTED_OPERATORS.include?(operator)
      @errors << "#{context} invalid operator '#{operator}'. Must be one of: #{SUPPORTED_OPERATORS.join(', ')}"
    end

    # Validate value based on operator
    case operator
    when 'between'
      unless rule['value'].is_a?(Array) && rule['value'].length == 2
        @errors << "#{context} 'between' operator requires array value with 2 elements"
      end
    when 'contains_keywords'
      unless rule['value'].is_a?(Array)
        @errors << "#{context} 'contains_keywords' operator requires array value"
      end
    end
  end

  def validate_actions(actions, context)
    unless actions.is_a?(Array)
      @errors << "#{context} actions must be an array"
      return
    end

    actions.each_with_index do |action, action_index|
      validate_single_action(action, "#{context}.actions[#{action_index}]")
    end
  end

  def validate_single_action(action, context)
    unless action['type'].present?
      @errors << "#{context} missing required 'type'"
    end

    unless SUPPORTED_ACTIONS.include?(action['type'])
      @errors << "#{context} invalid action type '#{action['type']}'. Must be one of: #{SUPPORTED_ACTIONS.join(', ')}"
    end

    # Validate config based on action type
    case action['type']
    when 'generate_dynamic_question'
      validate_dynamic_question_config(action['config'], context)
    when 'trigger_notification'
      validate_notification_config(action['config'], context)
    end
  end

  def validate_dynamic_question_config(config, context)
    unless config.is_a?(Hash)
      @errors << "#{context} dynamic_question config must be a hash"
      return
    end

    unless config['prompt_strategy'].present?
      @errors << "#{context} dynamic_question config missing 'prompt_strategy'"
    end

    unless config['question_type'].present?
      @errors << "#{context} dynamic_question config missing 'question_type'"
    end

    if config['prompt_template'].present?
      unless config['prompt_template'].is_a?(Hash)
        @errors << "#{context} prompt_template must be a hash"
      end
    end
  end

  def validate_notification_config(config, context)
    unless config.is_a?(Hash)
      @errors << "#{context} notification config must be a hash"
      return
    end

    unless config['type'].present?
      @errors << "#{context} notification config missing 'type'"
    end

    unless config['channels'].is_a?(Array)
      @errors << "#{context} notification config channels must be an array"
    end
  end

  def validate_execution_config(config, context)
    return unless config.present?

    unless config.is_a?(Hash)
      @errors << "#{context} execution_config must be a hash"
      return
    end

    if config['max_executions_per_response']
      unless config['max_executions_per_response'].is_a?(Integer) && config['max_executions_per_response'] > 0
        @errors << "#{context} max_executions_per_response must be a positive integer"
      end
    end

    if config['cooldown_minutes']
      unless config['cooldown_minutes'].is_a?(Integer) && config['cooldown_minutes'] >= 0
        @errors << "#{context} cooldown_minutes must be a non-negative integer"
      end
    end
  end

  def validate_ai_engine_config
    ai_engine = @config['ai_engine']
    
    unless ai_engine['primary_model'].present?
      @errors << "ai_engine missing required 'primary_model'"
    end

    unless ai_engine['fallback_model'].present?
      @errors << "ai_engine missing required 'fallback_model'"
    end

    if ai_engine['max_tokens']
      unless ai_engine['max_tokens'].is_a?(Integer) && ai_engine['max_tokens'] > 0
        @errors << "ai_engine max_tokens must be a positive integer"
      end
    end

    if ai_engine['temperature']
      unless ai_engine['temperature'].is_a?(Numeric) && ai_engine['temperature'].between?(0, 2)
        @errors << "ai_engine temperature must be between 0 and 2"
      end
    end

    validate_rate_limiting(ai_engine['rate_limiting']) if ai_engine['rate_limiting']
    validate_response_validation(ai_engine['response_validation']) if ai_engine['response_validation']
  end

  def validate_rate_limiting(config)
    return unless config.present?

    unless config.is_a?(Hash)
      @errors << "rate_limiting must be a hash"
      return
    end

    if config['max_requests_per_minute']
      unless config['max_requests_per_minute'].is_a?(Integer) && config['max_requests_per_minute'] > 0
        @errors << "rate_limiting max_requests_per_minute must be a positive integer"
      end
    end

    if config['max_requests_per_hour']
      unless config['max_requests_per_hour'].is_a?(Integer) && config['max_requests_per_hour'] > 0
        @errors << "rate_limiting max_requests_per_hour must be a positive integer"
      end
    end

    unless config['backoff_strategy'].in?(%w[exponential linear fixed])
      @errors << "rate_limiting backoff_strategy must be one of: exponential, linear, fixed"
    end
  end

  def validate_response_validation(config)
    return unless config.present?

    unless config.is_a?(Hash)
      @errors << "response_validation must be a hash"
      return
    end

    unless config['enabled'].in?([true, false])
      @errors << "response_validation enabled must be true or false"
    end

    if config['required_fields']
      unless config['required_fields'].is_a?(Array)
        @errors << "response_validation required_fields must be an array"
      end
    end

    if config['max_title_length']
      unless config['max_title_length'].is_a?(Integer) && config['max_title_length'] > 0
        @errors << "response_validation max_title_length must be a positive integer"
      end
    end

    if config['allowed_question_types']
      unless config['allowed_question_types'].is_a?(Array)
        @errors << "response_validation allowed_question_types must be an array"
      end
    end
  end
end