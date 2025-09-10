# frozen_string_literal: true

class AIMonitoringService
  include Singleton
  
  def initialize
    @alert_thresholds = {
      error_rate: 0.05, # 5% errors
      low_confidence_rate: 0.3, # 30% low confidence
      daily_cost_limit: 100.0, # $100 per day
      response_time: 30.0, # 30 seconds average
      queue_size: 100, # 100 jobs in queue
      circuit_breaker_failures: 5 # 5 failures to open
    }
    
    @notification_channels = %w[email slack webhook]
  end
  
  def check_system_health
    health_report = {
      timestamp: Time.current,
      status: 'healthy',
      alerts: [],
      metrics: AIMetricsCollector.collect_real_time_metrics,
      recommendations: AIMetricsCollector.generate_optimization_recommendations
    }
    
    # Check error rate
    error_rate = calculate_recent_error_rate(1.hour.ago)
    if error_rate > @alert_thresholds[:error_rate]
      health_report[:alerts] << create_alert('high_error_rate', error_rate)
      health_report[:status] = 'degraded'
    end
    
    # Check costs
    daily_cost = calculate_daily_cost
    if daily_cost > @alert_thresholds[:daily_cost_limit]
      health_report[:alerts] << create_alert('cost_exceeded', daily_cost)
      health_report[:status] = 'warning'
    end
    
    # Check generation quality
    low_confidence_rate = calculate_low_confidence_rate(1.hour.ago)
    if low_confidence_rate > @alert_thresholds[:low_confidence_rate]
      health_report[:alerts] << create_alert('low_quality_generation', low_confidence_rate)
    end
    
    # Check system load
    if system_overloaded?
      health_report[:alerts] << create_alert('system_overload', calculate_system_load)
      health_report[:status] = 'warning'
    end
    
    # Check queue size
    queue_size = Sidekiq::Queue.new('ai_processing').size
    if queue_size > @alert_thresholds[:queue_size]
      health_report[:alerts] << create_alert('queue_backlog', queue_size)
    end
    
    health_report
  end
  
  def send_alerts_if_needed(health_report)
    return if health_report[:alerts].empty?
    
    health_report[:alerts].each do |alert|
      case alert[:severity]
      when 'critical'
        send_immediate_alert(alert)
      when 'warning'
        send_daily_digest_alert(alert)
      when 'info'
        send_weekly_summary_alert(alert)
      end
    end
  end
  
  def monitor_rule_performance(rule_id, period = 7.days)
    performance = analyze_rule_performance(rule_id, period)
    
    if performance[:success_rate] < 30.0
      alert = create_rule_performance_alert(rule_id, performance)
      send_immediate_alert(alert)
    end
    
    performance
  end
  
  def track_api_costs(cost_data)
    key = "ai_costs:#{Date.current}"
    current_costs = Rails.cache.read(key) || 0.0
    Rails.cache.write(key, current_costs + cost_data[:cost], expires_in: 1.day)
    
    # Check if we've exceeded daily limit
    if current_costs + cost_data[:cost] > @alert_thresholds[:daily_cost_limit]
      alert = create_cost_alert(cost_data[:cost], current_costs + cost_data[:cost])
      send_immediate_alert(alert)
    end
  end
  
  def generate_daily_report
    date = Date.yesterday
    metrics = AIMetricsCollector.collect_daily_metrics(date)
    recommendations = AIMetricsCollector.generate_optimization_recommendations
    
    report = {
      date: date,
      metrics: metrics,
      recommendations: recommendations,
      summary: build_daily_summary(metrics, recommendations)
    }
    
    send_daily_report(report)
    report
  end
  
  private
  
  def create_alert(type, value)
    {
      type: type,
      value: value,
      severity: determine_severity(type, value),
      message: generate_alert_message(type, value),
      timestamp: Time.current,
      recommended_action: get_recommended_action(type),
      affected_forms: get_affected_forms(type)
    }
  end
  
  def create_rule_performance_alert(rule_id, performance)
    {
      type: 'rule_performance',
      rule_id: rule_id,
      severity: 'medium',
      message: "Rule '#{rule_id}' has low performance: #{performance[:success_rate]}% success rate",
      timestamp: Time.current,
      recommended_action: 'review_rule_conditions_and_prompts',
      performance_data: performance
    }
  end
  
  def create_cost_alert(current_cost, total_cost)
    {
      type: 'cost_threshold',
      current_cost: current_cost,
      total_cost: total_cost,
      severity: total_cost > 200.0 ? 'critical' : 'warning',
      message: "Daily AI cost threshold exceeded: $#{total_cost.round(2)}",
      timestamp: Time.current,
      recommended_action: 'review_usage_patterns_and_implement_cost_controls'
    }
  end
  
  def determine_severity(type, value)
    case type
    when 'high_error_rate'
      case value
      when 0.0..0.05 then 'info'
      when 0.05..0.1 then 'warning'
      else 'critical'
      end
    when 'cost_exceeded'
      case value
      when 0.0..50.0 then 'info'
      when 50.0..100.0 then 'warning'
      when 100.0..200.0 then 'warning'
      else 'critical'
      end
    when 'low_quality_generation'
      case value
      when 0.0..0.1 then 'info'
      when 0.1..0.2 then 'warning'
      else 'critical'
      end
    when 'system_overload'
      case value
      when 0.0..0.5 then 'info'
      when 0.5..0.8 then 'warning'
      else 'critical'
      end
    when 'queue_backlog'
      case value
      when 0..50 then 'info'
      when 50..100 then 'warning'
      else 'critical'
      end
    else
      'info'
    end
  end
  
  def generate_alert_message(type, value)
    case type
    when 'high_error_rate'
      "AI system error rate is #{value.round(3)} (threshold: #{@alert_thresholds[:error_rate]})"
    when 'cost_exceeded'
      "Daily AI costs of $#{value.round(2)} have exceeded the limit of $#{@alert_thresholds[:daily_cost_limit]}"
    when 'low_quality_generation'
      "#{value.round(3)} of AI generations have low confidence (threshold: #{@alert_thresholds[:low_confidence_rate]})"
    when 'system_overload'
      "System load is #{value.round(2)} (threshold: 0.8)"
    when 'queue_backlog'
      "AI processing queue has #{value} jobs (threshold: #{@alert_thresholds[:queue_size]})"
    else
      "Unknown alert: #{type} = #{value}"
    end
  end
  
  def get_recommended_action(type)
    case type
    when 'high_error_rate'
      'Check API status and review error logs for patterns'
    when 'cost_exceeded'
      'Review rate limiting settings and consider model downgrades'
    when 'low_quality_generation'
      'Improve prompt templates and validation rules'
    when 'system_overload'
      'Scale processing capacity or implement request throttling'
    when 'queue_backlog'
      'Add more workers or optimize job processing'
    else
      'Investigate and take appropriate action'
    end
  end
  
  def get_affected_forms(type)
    # Return forms that are affected by this alert
    case type
    when 'high_error_rate', 'cost_exceeded'
      Form.where(ai_enabled: true).limit(10)
    else
      []
    end
  end
  
  def send_immediate_alert(alert)
    Rails.logger.error("IMMEDIATE ALERT: #{alert[:message]}")
    
    # Send to configured channels
    @notification_channels.each do |channel|
      send_to_channel(channel, alert, :immediate)
    end
  end
  
  def send_daily_digest_alert(alert)
    Rails.logger.warn("DAILY ALERT: #{alert[:message]}")
    
    # Queue for daily digest
    Rails.cache.write(
      "daily_alerts:#{Date.current}",
      alert,
      expires_in: 1.day
    )
  end
  
  def send_weekly_summary_alert(alert)
    Rails.logger.info("WEEKLY ALERT: #{alert[:message]}")
    
    # Queue for weekly summary
    Rails.cache.write(
      "weekly_alerts:#{Date.current.strftime('%Y-%V')}",
      alert,
      expires_in: 1.week
    )
  end
  
  def send_to_channel(channel, alert, priority)
    case channel
    when 'email'
      AdminNotificationMailer.ai_alert(alert).deliver_later
    when 'slack'
      send_slack_notification(alert)
    when 'webhook'
      send_webhook_notification(alert)
    end
  end
  
  def send_slack_notification(alert)
    # Implementation depends on your Slack integration
    SlackNotifier.post(
      channel: '#ai-alerts',
      text: "🚨 AI Alert: #{alert[:message]}",
      attachments: [
        {
          color: alert_severity_color(alert[:severity]),
          fields: [
            { title: 'Type', value: alert[:type], short: true },
            { title: 'Severity', value: alert[:severity], short: true },
            { title: 'Action', value: alert[:recommended_action], short: false }
          ]
        }
      ]
    )
  end
  
  def send_webhook_notification(alert)
    # Send to configured webhook
    begin
      HTTParty.post(
        ENV['AI_ALERT_WEBHOOK_URL'],
        body: alert.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    rescue StandardError => e
      Rails.logger.error "Failed to send webhook alert: #{e.message}"
    end
  end
  
  def alert_severity_color(severity)
    case severity
    when 'critical' then 'danger'
    when 'warning' then 'warning'
    else 'good'
    end
  end
  
  def send_daily_report(report)
    # Send comprehensive daily report
    AdminNotificationMailer.daily_ai_report(report).deliver_later
    
    # Also send to Slack
    send_slack_daily_summary(report)
  end
  
  def send_slack_daily_summary(report)
    summary = "📊 Daily AI Report for #{report[:date]}\n"
    summary += "Executions: #{report[:metrics][:total_ai_executions]}\n"
    summary += "Questions Generated: #{report[:metrics][:questions_generated]}\n"
    summary += "Success Rate: #{report[:metrics][:success_rate]}%\n"
    summary += "Daily Cost: $#{report[:metrics][:cost_analysis]}"
    
    SlackNotifier.post(
      channel: '#ai-reports',
      text: summary
    )
  end
  
  def build_daily_summary(metrics, recommendations)
    {
      total_executions: metrics[:total_ai_executions],
      questions_generated: metrics[:questions_generated],
      success_rate: metrics[:success_rate],
      total_cost: metrics[:cost_analysis],
      recommendations_count: recommendations.length,
      critical_issues: recommendations.select { |r| r[:priority] == 'high' }.count
    }
  end
  
  def analyze_rule_performance(rule_id, period)
    questions = DynamicQuestion.generated_by_rule(rule_id)
                              .where('created_at > ?', period.ago)
    
    return { success_rate: 0.0, count: 0 } if questions.empty?
    
    answered = questions.answered.count
    total = questions.count
    
    {
      success_rate: (answered.to_f / total * 100).round(2),
      count: total,
      answered: answered,
      average_confidence: questions.average(:ai_confidence) || 0.0
    }
  end
  
  def calculate_recent_error_rate(since_time)
    recent_errors = count_recent_errors(since_time)
    total_recent = count_recent_executions(since_time)
    
    return 0.0 if total_recent.zero?
    (recent_errors.to_f / total_recent).round(3)
  end
  
  def calculate_daily_cost
    key = "ai_costs:#{Date.current}"
    Rails.cache.read(key) || 0.0
  end
  
  def calculate_low_confidence_rate(since_time)
    questions = DynamicQuestion.where(created_at: since_time..Time.current)
    return 0.0 if questions.empty?
    
    low_confidence = questions.where('ai_confidence < ?', 0.7).count
    (low_confidence.to_f / questions.count).round(3)
  end
  
  def system_overloaded?
    active_jobs = Sidekiq::Workers.new.size
    queue_size = Sidekiq::Queue.new('ai_processing').size
    
    active_jobs > 50 || queue_size > 100
  end
  
  def calculate_system_load
    active_jobs = Sidekiq::Workers.new.size
    max_capacity = 100 # Configurable
    (active_jobs.to_f / max_capacity).round(2)
  end
  
  def count_recent_executions(since_time)
    begin
      LogEntry.where(
        event_type: 'universal_ai_workflow_executed',
        created_at: since_time..Time.current
      ).count
    rescue StandardError
      0
    end
  end
end