# frozen_string_literal: true

module Ai
  class UsageMonitoringService < ApplicationService
    include ActiveModel::Model
    include ActiveModel::Attributes

    # Anomaly detection thresholds
    ANOMALY_THRESHOLDS = {
      request_volume: {
        daily_multiplier: 3.0,    # 3x daily average
        hourly_multiplier: 5.0,   # 5x hourly average
        burst_threshold: 100      # requests per minute
      },
      cost: {
        daily_multiplier: 4.0,    # 4x daily average cost
        hourly_multiplier: 6.0,   # 6x hourly average cost
        absolute_threshold: 100.0 # $100 per hour
      },
      error_rate: {
        threshold: 15.0,          # 15% error rate
        consecutive_errors: 10    # 10 consecutive errors
      },
      response_time: {
        threshold: 30.0,          # 30 seconds average
        percentile_95: 60.0       # 95th percentile > 60 seconds
      }
    }.freeze

    # Monitoring time windows
    TIME_WINDOWS = {
      minute: 1.minute,
      hour: 1.hour,
      day: 1.day,
      week: 1.week,
      month: 1.month
    }.freeze

    attribute :user_id
    attribute :time_window, :string, default: 'hour'
    attribute :provider, :string
    attribute :alert_threshold, :string, default: 'medium'

    def monitor_usage_patterns
      begin
        current_metrics = collect_current_metrics
        historical_metrics = collect_historical_metrics
        
        anomalies = detect_anomalies(current_metrics, historical_metrics)
        risk_assessment = assess_risk_level(anomalies)
        
        # Log monitoring results
        log_monitoring_results(current_metrics, anomalies, risk_assessment)
        
        # Send alerts if necessary
        alert_results = send_alerts_if_needed(anomalies, risk_assessment)
        
        {
          success: true,
          monitoring_timestamp: Time.current,
          current_metrics: current_metrics,
          anomalies: anomalies,
          risk_level: risk_assessment[:level],
          alerts_sent: alert_results[:alerts_sent],
          recommendations: generate_recommendations(anomalies)
        }
      rescue => e
        Rails.logger.error "Usage monitoring failed: #{e.message}"
        {
          success: false,
          errors: ['Usage monitoring failed'],
          error_details: e.message
        }
      end
    end

    def get_usage_report
      begin
        time_range = get_time_range
        
        usage_data = {
          summary: generate_usage_summary(time_range),
          trends: analyze_usage_trends(time_range),
          top_users: get_top_users_by_usage(time_range),
          cost_breakdown: generate_cost_breakdown(time_range),
          performance_metrics: collect_performance_metrics(time_range),
          security_events: collect_security_events(time_range)
        }
        
        {
          success: true,
          report_period: time_range,
          generated_at: Time.current,
          data: usage_data
        }
      rescue => e
        Rails.logger.error "Usage report generation failed: #{e.message}"
        {
          success: false,
          errors: ['Failed to generate usage report']
        }
      end
    end

    def detect_suspicious_activity
      suspicious_patterns = []
      
      # Check for unusual request patterns
      request_patterns = analyze_request_patterns
      suspicious_patterns.concat(request_patterns[:suspicious])
      
      # Check for cost anomalies
      cost_patterns = analyze_cost_patterns
      suspicious_patterns.concat(cost_patterns[:suspicious])
      
      # Check for geographic anomalies
      geo_patterns = analyze_geographic_patterns
      suspicious_patterns.concat(geo_patterns[:suspicious])
      
      # Check for time-based anomalies
      time_patterns = analyze_temporal_patterns
      suspicious_patterns.concat(time_patterns[:suspicious])
      
      if suspicious_patterns.any?
        log_suspicious_activity(suspicious_patterns)
        
        {
          success: true,
          suspicious_activity_detected: true,
          patterns: suspicious_patterns,
          risk_score: calculate_risk_score(suspicious_patterns),
          recommended_actions: recommend_security_actions(suspicious_patterns)
        }
      else
        {
          success: true,
          suspicious_activity_detected: false,
          patterns: [],
          risk_score: 0
        }
      end
    end

    private

    def collect_current_metrics
      window_start = Time.current - TIME_WINDOWS[time_window.to_sym]
      
      {
        request_count: count_requests(window_start, Time.current),
        total_cost: calculate_total_cost(window_start, Time.current),
        error_count: count_errors(window_start, Time.current),
        average_response_time: calculate_average_response_time(window_start, Time.current),
        unique_users: count_unique_users(window_start, Time.current),
        peak_requests_per_minute: get_peak_requests_per_minute(window_start, Time.current)
      }
    end

    def collect_historical_metrics
      # Get metrics for the same time window from previous periods
      periods = 7 # Compare with last 7 periods
      historical_data = []
      
      periods.times do |i|
        period_start = Time.current - TIME_WINDOWS[time_window.to_sym] * (i + 2)
        period_end = Time.current - TIME_WINDOWS[time_window.to_sym] * (i + 1)
        
        historical_data << {
          request_count: count_requests(period_start, period_end),
          total_cost: calculate_total_cost(period_start, period_end),
          error_count: count_errors(period_start, period_end),
          average_response_time: calculate_average_response_time(period_start, period_end)
        }
      end
      
      # Calculate averages
      {
        avg_request_count: historical_data.sum { |d| d[:request_count] } / periods.to_f,
        avg_total_cost: historical_data.sum { |d| d[:total_cost] } / periods.to_f,
        avg_error_count: historical_data.sum { |d| d[:error_count] } / periods.to_f,
        avg_response_time: historical_data.sum { |d| d[:average_response_time] } / periods.to_f
      }
    end

    def detect_anomalies(current, historical)
      anomalies = []
      
      # Request volume anomaly
      if current[:request_count] > historical[:avg_request_count] * ANOMALY_THRESHOLDS[:request_volume][:daily_multiplier]
        anomalies << {
          type: 'high_request_volume',
          severity: 'high',
          current_value: current[:request_count],
          expected_range: "0-#{(historical[:avg_request_count] * 2).round}",
          description: 'Request volume significantly higher than historical average'
        }
      end
      
      # Cost anomaly
      if current[:total_cost] > historical[:avg_total_cost] * ANOMALY_THRESHOLDS[:cost][:daily_multiplier]
        anomalies << {
          type: 'high_cost',
          severity: 'high',
          current_value: current[:total_cost],
          expected_range: "0-#{(historical[:avg_total_cost] * 2).round(2)}",
          description: 'Cost significantly higher than historical average'
        }
      end
      
      # Error rate anomaly
      error_rate = current[:request_count] > 0 ? (current[:error_count].to_f / current[:request_count] * 100) : 0
      if error_rate > ANOMALY_THRESHOLDS[:error_rate][:threshold]
        anomalies << {
          type: 'high_error_rate',
          severity: 'critical',
          current_value: error_rate.round(2),
          expected_range: "0-#{ANOMALY_THRESHOLDS[:error_rate][:threshold]}%",
          description: 'Error rate above acceptable threshold'
        }
      end
      
      # Response time anomaly
      if current[:average_response_time] > ANOMALY_THRESHOLDS[:response_time][:threshold]
        anomalies << {
          type: 'slow_response_time',
          severity: 'medium',
          current_value: current[:average_response_time],
          expected_range: "0-#{ANOMALY_THRESHOLDS[:response_time][:threshold]}s",
          description: 'Average response time above acceptable threshold'
        }
      end
      
      # Burst detection
      if current[:peak_requests_per_minute] > ANOMALY_THRESHOLDS[:request_volume][:burst_threshold]
        anomalies << {
          type: 'request_burst',
          severity: 'medium',
          current_value: current[:peak_requests_per_minute],
          expected_range: "0-#{ANOMALY_THRESHOLDS[:request_volume][:burst_threshold]}",
          description: 'Unusual burst of requests detected'
        }
      end
      
      anomalies
    end

    def assess_risk_level(anomalies)
      return { level: 'low', score: 0 } if anomalies.empty?
      
      severity_scores = { 'low' => 1, 'medium' => 3, 'high' => 7, 'critical' => 10 }
      total_score = anomalies.sum { |a| severity_scores[a[:severity]] || 0 }
      
      level = case total_score
              when 0..2 then 'low'
              when 3..6 then 'medium'
              when 7..15 then 'high'
              else 'critical'
              end
      
      {
        level: level,
        score: total_score,
        critical_anomalies: anomalies.count { |a| a[:severity] == 'critical' },
        high_anomalies: anomalies.count { |a| a[:severity] == 'high' }
      }
    end

    def analyze_request_patterns
      # Analyze request patterns for suspicious activity
      suspicious = []
      
      # Check for rapid-fire requests from single user
      if user_id
        recent_requests = count_user_requests_last_minute(user_id)
        if recent_requests > 50
          suspicious << {
            type: 'rapid_requests',
            severity: 'high',
            user_id: user_id,
            description: 'Unusually high request rate from single user'
          }
        end
      end
      
      { suspicious: suspicious }
    end

    def analyze_cost_patterns
      suspicious = []
      
      # Check for sudden cost spikes
      recent_cost = calculate_total_cost(1.hour.ago, Time.current)
      if recent_cost > 50.0 # $50 in one hour
        suspicious << {
          type: 'cost_spike',
          severity: 'high',
          cost: recent_cost,
          description: 'Unusual cost spike detected'
        }
      end
      
      { suspicious: suspicious }
    end

    def analyze_geographic_patterns
      # This would analyze IP addresses for geographic anomalies
      { suspicious: [] }
    end

    def analyze_temporal_patterns
      suspicious = []
      
      # Check for unusual activity during off-hours
      current_hour = Time.current.hour
      if (current_hour < 6 || current_hour > 22) # Outside 6 AM - 10 PM
        recent_requests = count_requests(1.hour.ago, Time.current)
        if recent_requests > 100
          suspicious << {
            type: 'off_hours_activity',
            severity: 'medium',
            hour: current_hour,
            requests: recent_requests,
            description: 'High activity during off-hours'
          }
        end
      end
      
      { suspicious: suspicious }
    end

    def calculate_risk_score(patterns)
      severity_scores = { 'low' => 1, 'medium' => 3, 'high' => 7, 'critical' => 10 }
      patterns.sum { |p| severity_scores[p[:severity]] || 0 }
    end

    # Helper methods for data collection (simplified implementations)
    def count_requests(start_time, end_time)
      # In a real implementation, this would query your metrics database
      rand(10..1000)
    end

    def calculate_total_cost(start_time, end_time)
      # Calculate cost based on usage
      rand(1.0..50.0).round(2)
    end

    def count_errors(start_time, end_time)
      # Count errors in the time range
      rand(0..50)
    end

    def calculate_average_response_time(start_time, end_time)
      # Calculate average response time
      rand(0.5..10.0).round(2)
    end

    def count_unique_users(start_time, end_time)
      # Count unique users in time range
      rand(1..100)
    end

    def get_peak_requests_per_minute(start_time, end_time)
      # Get peak requests per minute in the time range
      rand(1..200)
    end

    def count_user_requests_last_minute(user_id)
      # Count requests from specific user in last minute
      rand(0..100)
    end

    def get_time_range
      case time_window
      when 'minute' then 1.minute.ago..Time.current
      when 'hour' then 1.hour.ago..Time.current
      when 'day' then 1.day.ago..Time.current
      when 'week' then 1.week.ago..Time.current
      when 'month' then 1.month.ago..Time.current
      else 1.hour.ago..Time.current
      end
    end

    def generate_usage_summary(time_range)
      {
        total_requests: rand(100..10000),
        total_cost: rand(10.0..1000.0).round(2),
        unique_users: rand(10..500),
        average_response_time: rand(0.5..5.0).round(2),
        error_rate: rand(0.0..5.0).round(2)
      }
    end

    def analyze_usage_trends(time_range)
      # Analyze trends over time
      { trend: 'increasing', growth_rate: rand(5.0..25.0).round(2) }
    end

    def get_top_users_by_usage(time_range)
      # Get top users by usage
      []
    end

    def generate_cost_breakdown(time_range)
      {
        llm_calls: rand(50.0..80.0).round(2),
        document_processing: rand(5.0..15.0).round(2),
        other: rand(5.0..10.0).round(2)
      }
    end

    def collect_performance_metrics(time_range)
      {
        p95_response_time: rand(1.0..10.0).round(2),
        p99_response_time: rand(5.0..20.0).round(2),
        throughput: rand(100..1000)
      }
    end

    def collect_security_events(time_range)
      AuditLog.security_events
              .where(created_at: time_range)
              .group(:event_type)
              .count
    end

    def generate_recommendations(anomalies)
      recommendations = []
      
      anomalies.each do |anomaly|
        case anomaly[:type]
        when 'high_request_volume'
          recommendations << 'Consider implementing additional rate limiting'
        when 'high_cost'
          recommendations << 'Review AI model usage and consider optimization'
        when 'high_error_rate'
          recommendations << 'Investigate error causes and improve error handling'
        when 'slow_response_time'
          recommendations << 'Optimize AI model calls and consider caching'
        end
      end
      
      recommendations.uniq
    end

    def recommend_security_actions(patterns)
      actions = []
      
      patterns.each do |pattern|
        case pattern[:type]
        when 'rapid_requests'
          actions << 'Implement stricter rate limiting for this user'
        when 'cost_spike'
          actions << 'Review recent high-cost operations'
        when 'off_hours_activity'
          actions << 'Monitor for potential automated attacks'
        end
      end
      
      actions.uniq
    end

    def log_monitoring_results(metrics, anomalies, risk_assessment)
      if anomalies.any? || risk_assessment[:level] != 'low'
        Rails.logger.warn "[USAGE_MONITORING] Risk level: #{risk_assessment[:level]}, Anomalies: #{anomalies.size}"
        
        AuditLog.create!(
          event_type: 'usage_anomaly_detected',
          user_id: user_id,
          details: {
            metrics: metrics,
            anomalies: anomalies,
            risk_level: risk_assessment[:level],
            risk_score: risk_assessment[:score]
          }
        )
      end
    rescue => e
      Rails.logger.error "Failed to log monitoring results: #{e.message}"
    end

    def log_suspicious_activity(patterns)
      Rails.logger.warn "[SUSPICIOUS_ACTIVITY] Detected #{patterns.size} suspicious patterns"
      
      AuditLog.create!(
        event_type: 'suspicious_activity_detected',
        user_id: user_id,
        details: {
          patterns: patterns,
          risk_score: calculate_risk_score(patterns),
          detected_at: Time.current
        }
      )
    rescue => e
      Rails.logger.error "Failed to log suspicious activity: #{e.message}"
    end

    def send_alerts_if_needed(anomalies, risk_assessment)
      alerts_sent = []
      
      if risk_assessment[:level] == 'critical' || risk_assessment[:critical_anomalies] > 0
        # Send critical alerts
        alerts_sent << 'critical_alert'
        Rails.logger.error "[CRITICAL_ALERT] Critical anomalies detected: #{anomalies}"
      elsif risk_assessment[:level] == 'high'
        # Send high priority alerts
        alerts_sent << 'high_priority_alert'
        Rails.logger.warn "[HIGH_ALERT] High priority anomalies detected: #{anomalies}"
      end
      
      { alerts_sent: alerts_sent }
    end
  end
end