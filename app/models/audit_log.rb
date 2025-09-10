# frozen_string_literal: true

class AuditLog < ApplicationRecord
  belongs_to :user, optional: true

  validates :event_type, presence: true
  validates :ip_address, presence: false
  validate :valid_ip_address_format, if: -> { ip_address.present? }

  scope :security_events, -> { where(event_type: security_event_types) }
  scope :recent, -> { order(created_at: :desc) }
  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :admin_actions, -> { where(event_type: 'admin_action') }
  scope :failed_attempts, -> { where(event_type: ['sql_injection_attempt', 'xss_attempt', 'csrf_failure', 'unauthorized_admin_access']) }
  scope :by_ip, ->(ip) { where(ip_address: ip) }
  scope :today, -> { where(created_at: Date.current.beginning_of_day..Date.current.end_of_day) }

  def self.security_event_types
    [
      'file_validation_failed',
      'suspicious_content_detected',
      'inappropriate_content_detected',
      'rate_limit_exceeded',
      'prompt_injection_attempt',
      'api_key_rotation',
      'usage_anomaly_detected',
      'admin_rate_limit_exceeded',
      'sql_injection_attempt',
      'xss_attempt',
      'csrf_failure',
      'unauthorized_admin_access',
      'suspicious_admin_activity'
    ]
  end

  def security_event?
    self.class.security_event_types.include?(event_type)
  end

  def admin_action?
    event_type == 'admin_action'
  end

  def failed_security_attempt?
    %w[sql_injection_attempt xss_attempt csrf_failure unauthorized_admin_access].include?(event_type)
  end

  # Class methods for security monitoring
  def self.suspicious_activity_for_ip(ip_address, hours = 24)
    where(ip_address: ip_address)
      .where(created_at: hours.hours.ago..Time.current)
      .failed_attempts
      .count
  end

  def self.admin_activity_summary(user_id, days = 7)
    admin_actions
      .for_user(user_id)
      .where(created_at: days.days.ago..Time.current)
      .group(:event_type)
      .count
  end

  def self.security_alerts_today
    security_events.today.count
  end

  def self.top_suspicious_ips(limit = 10)
    failed_attempts
      .where(created_at: 24.hours.ago..Time.current)
      .group(:ip_address)
      .order('count_id DESC')
      .limit(limit)
      .count(:id)
  end

  private

  def valid_ip_address_format
    return if ip_address.blank?
    
    begin
      # Use Ruby's built-in IPAddr class for proper IP validation
      IPAddr.new(ip_address)
    rescue IPAddr::InvalidAddressError
      errors.add(:ip_address, 'is not a valid IP address')
    end
  end
end