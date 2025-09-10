# frozen_string_literal: true

# Background job for monitoring admin security and generating alerts
class AdminSecurityMonitoringJob < ApplicationJob
  queue_as :default

  def perform
    monitoring_service = AdminMonitoringService.new
    alerts = monitoring_service.check_security_alerts
    
    # Process alerts
    alerts.each do |alert|
      process_alert(alert)
    end
    
    # Clean up old audit logs (keep last 90 days)
    cleanup_old_audit_logs
    
    # Log monitoring completion
    Rails.logger.info "Admin security monitoring completed. Found #{alerts.count} alerts."
  end

  private

  def process_alert(alert)
    case alert[:severity]
    when 'high'
      handle_high_severity_alert(alert)
    when 'medium'
      handle_medium_severity_alert(alert)
    else
      handle_low_severity_alert(alert)
    end
    
    # Log the alert
    AuditLog.create!(
      event_type: 'security_alert_generated',
      details: alert,
      ip_address: alert[:ip_address]
    )
  end

  def handle_high_severity_alert(alert)
    # For high severity alerts, we might want to:
    # 1. Send immediate notifications to admins
    # 2. Temporarily block suspicious IPs
    # 3. Log to external monitoring systems
    
    Rails.logger.error "HIGH SEVERITY SECURITY ALERT: #{alert[:message]}"
    
    # Send notification to all superadmins
    notify_superadmins(alert)
    
    # If it's a coordinated attack, consider temporary IP blocking
    if alert[:type] == 'coordinated_attack'
      consider_ip_blocking(alert[:ip_address])
    end
  end

  def handle_medium_severity_alert(alert)
    Rails.logger.warn "MEDIUM SEVERITY SECURITY ALERT: #{alert[:message]}"
    
    # For medium severity, log and potentially notify during business hours
    notify_superadmins(alert) if business_hours?
  end

  def handle_low_severity_alert(alert)
    Rails.logger.info "LOW SEVERITY SECURITY ALERT: #{alert[:message]}"
    
    # Just log low severity alerts for review
  end

  def notify_superadmins(alert)
    superadmins = User.where(role: 'superadmin')
    
    superadmins.find_each do |admin|
      # In a real implementation, you might send emails or Slack notifications
      # For now, we'll just create an audit log entry
      AuditLog.create!(
        user: admin,
        event_type: 'security_alert_notification',
        details: {
          alert_type: alert[:type],
          alert_message: alert[:message],
          alert_severity: alert[:severity],
          notified_at: Time.current
        }
      )
    end
  end

  def consider_ip_blocking(ip_address)
    return if ip_address.blank?
    
    # In a real implementation, you might:
    # 1. Add IP to a blocklist in Redis
    # 2. Update firewall rules
    # 3. Notify infrastructure team
    
    Rails.logger.error "CONSIDERING IP BLOCK for #{ip_address} due to coordinated attack"
    
    # For now, just log the recommendation
    AuditLog.create!(
      event_type: 'ip_block_recommendation',
      details: {
        ip_address: ip_address,
        reason: 'coordinated_attack',
        recommended_at: Time.current
      },
      ip_address: ip_address
    )
  end

  def business_hours?
    # Simple business hours check (9 AM - 5 PM UTC, Monday-Friday)
    time = Time.current.utc
    time.wday.between?(1, 5) && time.hour.between?(9, 17)
  end

  def cleanup_old_audit_logs
    # Keep audit logs for 90 days
    cutoff_date = 90.days.ago
    
    old_logs_count = AuditLog.where('created_at < ?', cutoff_date).count
    
    if old_logs_count > 0
      AuditLog.where('created_at < ?', cutoff_date).delete_all
      
      Rails.logger.info "Cleaned up #{old_logs_count} old audit log entries"
      
      # Log the cleanup
      AuditLog.create!(
        event_type: 'audit_log_cleanup',
        details: {
          deleted_count: old_logs_count,
          cutoff_date: cutoff_date,
          cleaned_at: Time.current
        }
      )
    end
  end
end