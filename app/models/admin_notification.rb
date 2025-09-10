class AdminNotification < ApplicationRecord
  belongs_to :user, optional: true

  # Event types
  EVENT_TYPES = {
    user_registered: 'user_registered',
    user_upgraded: 'user_upgraded',
    user_downgraded: 'user_downgraded',
    trial_started: 'trial_started',
    trial_expired: 'trial_expired',
    trial_ending_soon: 'trial_ending_soon',
    payment_failed: 'payment_failed',
    payment_succeeded: 'payment_succeeded',
    form_created: 'form_created',
    form_published: 'form_published',
    high_response_volume: 'high_response_volume',
    integration_connected: 'integration_connected',
    integration_failed: 'integration_failed',
    user_inactive: 'user_inactive',
    suspicious_activity: 'suspicious_activity',
    system: 'system'
  }.freeze

  # Priorities
  PRIORITIES = {
    low: 'low',
    normal: 'normal',
    high: 'high',
    critical: 'critical'
  }.freeze

  # Categories
  CATEGORIES = {
    user_activity: 'user_activity',
    billing: 'billing',
    system: 'system',
    security: 'security'
  }.freeze

  validates :event_type, presence: true, inclusion: { in: EVENT_TYPES.values }
  validates :title, presence: true
  validates :priority, inclusion: { in: PRIORITIES.values }
  validates :category, inclusion: { in: CATEGORIES.values }, allow_nil: true

  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where.not(read_at: nil) }
  scope :by_priority, ->(priority) { where(priority: priority) }
  scope :by_event_type, ->(event_type) { where(event_type: event_type) }
  scope :recent, -> { order(created_at: :desc) }
  scope :today, -> { where(created_at: Date.current.beginning_of_day..Date.current.end_of_day) }
  scope :this_week, -> { where(created_at: 1.week.ago..Time.current) }

  def read?
    read_at.present?
  end

  def unread?
    !read?
  end

  def mark_as_read!
    update!(read_at: Time.current) unless read?
  end

  def priority_color
    case priority
    when 'critical' then 'text-red-600 bg-red-50'
    when 'high' then 'text-orange-600 bg-orange-50'
    when 'normal' then 'text-blue-600 bg-blue-50'
    when 'low' then 'text-gray-600 bg-gray-50'
    else 'text-gray-600 bg-gray-50'
    end
  end

  def priority_icon
    case priority
    when 'critical' then '🚨'
    when 'high' then '⚠️'
    when 'normal' then 'ℹ️'
    when 'low' then '📝'
    else 'ℹ️'
    end
  end

  def event_icon
    case event_type
    when 'user_registered' then '👋'
    when 'user_upgraded' then '⬆️'
    when 'user_downgraded' then '⬇️'
    when 'trial_started' then '🆓'
    when 'trial_expired' then '⏰'
    when 'trial_ending_soon' then '⏳'
    when 'payment_failed' then '💳'
    when 'payment_succeeded' then '✅'
    when 'form_created' then '📝'
    when 'form_published' then '🚀'
    when 'high_response_volume' then '📈'
    when 'integration_connected' then '🔗'
    when 'integration_failed' then '❌'
    when 'user_inactive' then '😴'
    when 'suspicious_activity' then '🔍'
    when 'system' then '⚙️'
    else '📢'
    end
  end

  # Class methods for creating notifications
  class << self
    def notify_user_registered(user)
      create!(
        event_type: EVENT_TYPES[:user_registered],
        title: "New user registered",
        message: "#{user.email} has joined AgentForm",
        user: user,
        priority: PRIORITIES[:normal],
        category: CATEGORIES[:user_activity],
        metadata: {
          user_email: user.email,
          user_role: user.role,
          registration_time: user.created_at
        }
      )
    end

    def notify_user_upgraded(user, from_plan, to_plan)
      create!(
        event_type: EVENT_TYPES[:user_upgraded],
        title: "User upgraded subscription",
        message: "#{user.email} upgraded from #{from_plan} to #{to_plan}",
        user: user,
        priority: PRIORITIES[:high],
        category: CATEGORIES[:billing],
        metadata: {
          user_email: user.email,
          from_plan: from_plan,
          to_plan: to_plan,
          upgrade_time: Time.current
        }
      )
    end

    def notify_trial_started(user)
      create!(
        event_type: EVENT_TYPES[:trial_started],
        title: "Trial started",
        message: "#{user.email} started their premium trial",
        user: user,
        priority: PRIORITIES[:normal],
        category: CATEGORIES[:billing],
        metadata: {
          user_email: user.email,
          trial_start: user.trial_started_at,
          trial_end: user.trial_ends_at
        }
      )
    end

    def notify_trial_expired(user)
      create!(
        event_type: EVENT_TYPES[:trial_expired],
        title: "Trial expired",
        message: "#{user.email}'s premium trial has expired",
        user: user,
        priority: PRIORITIES[:high],
        category: CATEGORIES[:billing],
        metadata: {
          user_email: user.email,
          trial_end: user.trial_ends_at,
          expired_at: Time.current
        }
      )
    end

    def notify_payment_failed(user, amount, error_message = nil)
      create!(
        event_type: EVENT_TYPES[:payment_failed],
        title: "Payment failed",
        message: "Payment of $#{amount} failed for #{user.email}",
        user: user,
        priority: PRIORITIES[:high],
        category: CATEGORIES[:billing],
        metadata: {
          user_email: user.email,
          amount: amount,
          error_message: error_message,
          failed_at: Time.current
        }
      )
    end

    def notify_high_response_volume(user, form, response_count)
      create!(
        event_type: EVENT_TYPES[:high_response_volume],
        title: "High response volume detected",
        message: "Form '#{form.title}' by #{user.email} received #{response_count} responses today",
        user: user,
        priority: PRIORITIES[:normal],
        category: CATEGORIES[:user_activity],
        metadata: {
          user_email: user.email,
          form_id: form.id,
          form_title: form.title,
          response_count: response_count,
          detected_at: Time.current
        }
      )
    end

    def notify_suspicious_activity(user, activity_type, details)
      create!(
        event_type: EVENT_TYPES[:suspicious_activity],
        title: "Suspicious activity detected",
        message: "Suspicious #{activity_type} detected for #{user.email}",
        user: user,
        priority: PRIORITIES[:critical],
        category: CATEGORIES[:security],
        metadata: {
          user_email: user.email,
          activity_type: activity_type,
          details: details,
          detected_at: Time.current
        }
      )
    end
  end
end
