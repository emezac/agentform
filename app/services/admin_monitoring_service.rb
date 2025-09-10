# frozen_string_literal: true

# Service for monitoring admin activities and security events
class AdminMonitoringService
  include ActiveModel::Model
  include ActiveModel::Attributes

  # Security thresholds
  SUSPICIOUS_ACTIVITY_THRESHOLD = 5 # Failed attempts per IP per hour
  ADMIN_SESSION_TIMEOUT = 2.hours
  MAX_ADMIN_ACTIONS_PER_HOUR = 100

  def initialize
    @alerts = []
  end

  # Check for suspicious activity and generate alerts
  def check_security_alerts
    check_suspicious_ips
    check_admin_activity_anomalies
    check_failed_login_patterns
    check_session_security
    
    @alerts
  end

  # Get security dashboard data
  def security_dashboard_data
    {
      security_alerts_today: AuditLog.security_alerts_today,
      failed_attempts_last_hour: failed_attempts_last_hour,
      top_suspicious_ips: AuditLog.top_suspicious_ips(5),
      admin_activity_summary: admin_activity_last_24h,
      recent_security_events: recent_security_events(10)
    }
  end

  # Monitor specific user's admin activity
  def monitor_user_activity(user_id, days = 7)
    return {} unless user_id

    {
      total_actions: AuditLog.admin_actions.for_user(user_id).where(created_at: days.days.ago..Time.current).count,
      activity_by_day: activity_by_day(user_id, days),
      most_common_actions: most_common_actions(user_id, days),
      security_events: AuditLog.security_events.for_user(user_id).where(created_at: days.days.ago..Time.current).count,
      last_activity: AuditLog.for_user(user_id).recent.first&.created_at
    }
  end

  # Check if IP should be blocked
  def should_block_ip?(ip_address)
    return false if ip_address.blank?
    
    suspicious_count = AuditLog.suspicious_activity_for_ip(ip_address, 1)
    suspicious_count >= SUSPICIOUS_ACTIVITY_THRESHOLD
  end

  # Generate security report
  def generate_security_report(start_date = 7.days.ago, end_date = Time.current)
    {
      period: "#{start_date.strftime('%Y-%m-%d')} to #{end_date.strftime('%Y-%m-%d')}",
      total_security_events: security_events_in_period(start_date, end_date),
      security_events_by_type: security_events_by_type(start_date, end_date),
      top_targeted_ips: top_targeted_ips(start_date, end_date),
      admin_activity_summary: admin_activity_in_period(start_date, end_date),
      recommendations: generate_security_recommendations
    }
  end

  private

  def check_suspicious_ips
    suspicious_ips = AuditLog.top_suspicious_ips(10)
    
    suspicious_ips.each do |ip, count|
      if count >= SUSPICIOUS_ACTIVITY_THRESHOLD
        @alerts << {
          type: 'suspicious_ip',
          severity: count >= 10 ? 'high' : 'medium',
          message: "IP #{ip} has #{count} failed security attempts in the last 24 hours",
          ip_address: ip,
          count: count,
          created_at: Time.current
        }
      end
    end
  end

  def check_admin_activity_anomalies
    # Check for unusual admin activity patterns
    recent_admin_actions = AuditLog.admin_actions.where(created_at: 1.hour.ago..Time.current)
    
    # Group by user and check for excessive activity
    activity_by_user = recent_admin_actions.group(:user_id).count
    
    activity_by_user.each do |user_id, count|
      if count >= MAX_ADMIN_ACTIONS_PER_HOUR
        user = User.find_by(id: user_id)
        @alerts << {
          type: 'excessive_admin_activity',
          severity: 'medium',
          message: "User #{user&.email || user_id} performed #{count} admin actions in the last hour",
          user_id: user_id,
          count: count,
          created_at: Time.current
        }
      end
    end
  end

  def check_failed_login_patterns
    # Check for patterns in failed login attempts
    failed_attempts = AuditLog.where(
      event_type: ['csrf_failure', 'unauthorized_admin_access'],
      created_at: 1.hour.ago..Time.current
    )
    
    # Group by IP to find coordinated attacks
    attempts_by_ip = failed_attempts.group(:ip_address).count
    
    attempts_by_ip.each do |ip, count|
      if count >= 10
        @alerts << {
          type: 'coordinated_attack',
          severity: 'high',
          message: "Potential coordinated attack from IP #{ip} with #{count} failed attempts",
          ip_address: ip,
          count: count,
          created_at: Time.current
        }
      end
    end
  end

  def check_session_security
    # Check for session-related security issues
    session_events = AuditLog.where(
      event_type: ['suspicious_admin_activity', 'admin_session_expired'],
      created_at: 24.hours.ago..Time.current
    )
    
    if session_events.count >= 5
      @alerts << {
        type: 'session_security_issues',
        severity: 'medium',
        message: "Multiple session security events detected (#{session_events.count} in last 24h)",
        count: session_events.count,
        created_at: Time.current
      }
    end
  end

  def failed_attempts_last_hour
    AuditLog.failed_attempts.where(created_at: 1.hour.ago..Time.current).count
  end

  def admin_activity_last_24h
    AuditLog.admin_actions.where(created_at: 24.hours.ago..Time.current).group(:user_id).count
  end

  def recent_security_events(limit = 10)
    AuditLog.security_events.recent.limit(limit).includes(:user).map do |event|
      {
        id: event.id,
        event_type: event.event_type,
        user_email: event.user&.email,
        ip_address: event.ip_address,
        details: event.details,
        created_at: event.created_at
      }
    end
  end

  def activity_by_day(user_id, days)
    # Simple grouping by date without external gem dependency
    logs = AuditLog.admin_actions
                   .for_user(user_id)
                   .where(created_at: days.days.ago..Time.current)
                   .pluck(:created_at)
    
    logs.group_by { |date| date.to_date }.transform_values(&:count)
  end

  def most_common_actions(user_id, days)
    AuditLog.admin_actions
           .for_user(user_id)
           .where(created_at: days.days.ago..Time.current)
           .joins("JOIN json_extract(details, '$.action') as action")
           .group("json_extract(details, '$.action')")
           .count
           .sort_by { |_, count| -count }
           .first(5)
  rescue
    # Fallback if JSON extraction doesn't work
    {}
  end

  def security_events_in_period(start_date, end_date)
    AuditLog.security_events.where(created_at: start_date..end_date).count
  end

  def security_events_by_type(start_date, end_date)
    AuditLog.security_events
           .where(created_at: start_date..end_date)
           .group(:event_type)
           .count
  end

  def top_targeted_ips(start_date, end_date)
    AuditLog.failed_attempts
           .where(created_at: start_date..end_date)
           .group(:ip_address)
           .count
           .sort_by { |_, count| -count }
           .first(10)
  end

  def admin_activity_in_period(start_date, end_date)
    AuditLog.admin_actions
           .where(created_at: start_date..end_date)
           .group(:user_id)
           .count
  end

  def generate_security_recommendations
    recommendations = []
    
    # Check for high-risk IPs
    high_risk_ips = AuditLog.top_suspicious_ips(5)
    if high_risk_ips.any? { |_, count| count >= 20 }
      recommendations << "Consider implementing IP blocking for addresses with excessive failed attempts"
    end
    
    # Check for admin activity patterns
    admin_activity = AuditLog.admin_actions.where(created_at: 7.days.ago..Time.current).count
    if admin_activity > 1000
      recommendations << "High admin activity detected - review admin access logs for unusual patterns"
    end
    
    # Check for security event trends
    recent_events = AuditLog.security_events.where(created_at: 24.hours.ago..Time.current).count
    previous_events = AuditLog.security_events.where(created_at: 48.hours.ago..24.hours.ago).count
    
    if recent_events > previous_events * 2
      recommendations << "Security events have doubled in the last 24 hours - investigate potential threats"
    end
    
    recommendations << "Regularly review and rotate admin credentials" if recommendations.empty?
    
    recommendations
  end
end