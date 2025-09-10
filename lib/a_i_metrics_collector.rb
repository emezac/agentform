# frozen_string_literal: true

class AIMetricsCollector
  def self.collect_daily_metrics(date = Date.current)
    {
      total_ai_executions: count_ai_executions(date),
      questions_generated: count_dynamic_questions(date),
      success_rate: calculate_success_rate(date),
      average_confidence: calculate_average_confidence(date),
      rule_performance: analyze_rule_performance(date),
      cost_analysis: calculate_ai_costs(date),
      user_engagement: measure_user_engagement(date),
      system_health: check_system_health(date)
    }
  end

  def self.collect_real_time_metrics
    {
      active_processing_jobs: count_active_jobs,
      queue_size: Sidekiq::Queue.new('ai_processing').size,
      circuit_breaker_status: check_circuit_breaker_status,
      recent_errors: count_recent_errors(5.minutes.ago),
      hourly_costs: calculate_hourly_costs
    }
  end

  def self.generate_optimization_recommendations
    recommendations = []
    
    # Analyze rules with low performance
    low_performance_rules = identify_low_performance_rules
    if low_performance_rules.any?
      recommendations << {
        type: 'rule_optimization',
        priority: 'high',
        message: "Rules with <30% success rate need review: #{low_performance_rules.join(', ')}",
        action: 'review_rule_conditions',
        impact: 'high'
      }
    end

    # Analyze API costs
    daily_costs = calculate_daily_ai_costs
    if daily_costs > 50.0 # Configurable threshold
      recommendations << {
        type: 'cost_optimization', 
        priority: 'medium',
        message: "Daily AI costs exceeding $#{daily_costs}",
        action: 'review_rate_limits_and_model_selection',
        impact: 'medium'
      }
    end

    # Analyze generation quality
    low_confidence_rate = calculate_low_confidence_rate(1.hour.ago)
    if low_confidence_rate > 0.2 # More than 20% low confidence
      recommendations << {
        type: 'quality_improvement',
        priority: 'medium', 
        message: "#{(low_confidence_rate * 100).round}% of generations have low confidence",
        action: 'improve_prompts_and_validation',
        impact: 'medium'
      }
    end

    # Check for high error rates
    error_rate = calculate_error_rate(1.hour.ago)
    if error_rate > 0.05 # 5% error rate
      recommendations << {
        type: 'error_reduction',
        priority: 'high',
        message: "High error rate detected: #{error_rate.round(3)}",
        action: 'investigate_api_issues_and_retry_logic',
        impact: 'high'
      }
    end

    # Check for system overload
    if system_overloaded?
      recommendations << {
        type: 'performance_optimization',
        priority: 'high',
        message: 'System appears to be overloaded',
        action: 'scale_processing_capacity_or_throttle_requests',
        impact: 'high'
      }
    end

    recommendations
  end

  private

  def self.count_ai_executions(date)
    begin
      Rails.logger.silence do
        LogEntry.where(
          event_type: 'universal_ai_workflow_executed',
          created_at: date.beginning_of_day..date.end_of_day
        ).count
      end
    rescue StandardError
      0
    end
  end

  def self.count_dynamic_questions(date)
    DynamicQuestion.where(
      created_at: date.beginning_of_day..date.end_of_day
    ).count
  end

  def self.calculate_success_rate(date)
    total = DynamicQuestion.where(
      created_at: date.beginning_of_day..date.end_of_day
    ).count
    return 0.0 if total.zero?

    answered = DynamicQuestion.answered.where(
      created_at: date.beginning_of_day..date.end_of_day
    ).count
    (answered.to_f / total * 100).round(2)
  end

  def self.calculate_average_confidence(date)
    DynamicQuestion.where(
      created_at: date.beginning_of_day..date.end_of_day
    ).average(:ai_confidence) || 0.0
  end

  def self.analyze_rule_performance(date)
    rule_stats = {}
    
    # Get all rules that triggered dynamic questions
    DynamicQuestion.where(
      created_at: date.beginning_of_day..date.end_of_day
    ).find_each do |dq|
      rules = dq.generation_context['triggered_by_rules'] || []
      rules.each do |rule_id|
        rule_stats[rule_id] ||= { count: 0, answered: 0 }
        rule_stats[rule_id][:count] += 1
        rule_stats[rule_id][:answered] += 1 if dq.answered?
      end
    end

    rule_stats.transform_values do |stats|
      {
        total_generated: stats[:count],
        answered: stats[:answered],
        success_rate: stats[:count].zero? ? 0.0 : (stats[:answered].to_f / stats[:count] * 100).round(2)
      }
    end
  end

  def self.calculate_ai_costs(date)
    # Placeholder - implement actual cost calculation
    executions = count_ai_executions(date)
    executions * 0.01 # $0.01 per execution estimate
  end

  def self.measure_user_engagement(date)
    responses = FormResponse.where(
      created_at: date.beginning_of_day..date.end_of_day
    ).joins(:dynamic_questions)

    {
      total_responses: responses.count,
      responses_with_dynamic_questions: responses.distinct.count,
      average_dynamic_questions_per_response: responses.count.zero? ? 0.0 : responses.count.to_f / responses.distinct.count,
      completion_rate: calculate_dynamic_question_completion_rate(date)
    }
  end

  def self.calculate_dynamic_question_completion_rate(date)
    dynamic_questions = DynamicQuestion.where(
      created_at: date.beginning_of_day..date.end_of_day
    )
    return 0.0 if dynamic_questions.empty?

    answered = dynamic_questions.answered.count
    (answered.to_f / dynamic_questions.count * 100).round(2)
  end

  def self.check_system_health(date)
    {
      total_executions: count_ai_executions(date),
      error_rate: calculate_error_rate(date),
      average_response_time: calculate_average_response_time(date),
      peak_hour_load: calculate_peak_hour_load(date)
    }
  end

  def self.count_active_jobs
    Sidekiq::Workers.new.size
  end

  def self.check_circuit_breaker_status
    # This would depend on your circuit breaker implementation
    'closed' # Placeholder
  end

  def self.count_recent_errors(since_time)
    LogEntry.where(
      event_type: 'ai_workflow_error',
      created_at: since_time..Time.current
    ).count
  end

  def self.calculate_hourly_costs
    # Calculate costs for the current hour
    hour_start = Time.current.beginning_of_hour
    executions = count_ai_executions(Date.current) # Simplified
    executions * 0.01
  end

  def self.identify_low_performance_rules
    rule_performance = analyze_rule_performance(Date.current)
    rule_performance.select { |rule_id, stats| stats[:success_rate] < 30.0 }.keys
  end

  def self.calculate_daily_ai_costs
    calculate_ai_costs(Date.current)
  end

  def self.calculate_low_confidence_rate(since_time)
    questions = DynamicQuestion.where(created_at: since_time..Time.current)
    return 0.0 if questions.empty?

    low_confidence = questions.where('ai_confidence < ?', 0.7).count
    (low_confidence.to_f / questions.count).round(3)
  end

  def self.calculate_error_rate(since_time)
    total_executions = count_ai_executions(Date.current) # Simplified
    return 0.0 if total_executions.zero?

    recent_errors = count_recent_errors(since_time)
    (recent_errors.to_f / total_executions).round(3)
  end

  def self.calculate_average_response_time(date)
    # Placeholder - implement actual timing
    2.5 # seconds
  end

  def self.calculate_peak_hour_load(date)
    # Placeholder - implement actual peak analysis
    100 # arbitrary units
  end

  def self.system_overloaded?
    active_jobs = count_active_jobs
    queue_size = Sidekiq::Queue.new('ai_processing').size
    
    active_jobs > 50 || queue_size > 100
  end

  def self.export_metrics_csv(date = Date.current)
    metrics = collect_daily_metrics(date)
    
    CSV.generate(headers: true) do |csv|
      csv << ['Metric', 'Value', 'Date']
      
      metrics.each do |metric, value|
        if value.is_a?(Hash)
          value.each do |sub_metric, sub_value|
            csv << ["#{metric}_#{sub_metric}", sub_value, date]
          end
        else
          csv << [metric, value, date]
        end
      end
    end
  end
end