class AdminNotificationService < ApplicationService
  def self.notify(event_type, **options)
    new(event_type, **options).call
  end

  def initialize(event_type, **options)
    @event_type = event_type
    @options = options
  end

  def call
    return unless should_notify?

    notification = create_notification
    broadcast_notification(notification) if notification.persisted?
    notification
  end

  private

  attr_reader :event_type, :options

  def should_notify?
    # Skip notifications in test environment unless explicitly enabled
    return false if Rails.env.test? && !options[:force_in_test]
    
    # Skip if event type is not valid
    return false unless AdminNotification::EVENT_TYPES.value?(event_type.to_s)
    
    # Skip duplicate notifications for certain events
    return false if duplicate_notification_exists?
    
    true
  end

  def create_notification
    case event_type.to_s
    when 'user_registered'
      AdminNotification.notify_user_registered(options[:user])
    when 'user_upgraded'
      AdminNotification.notify_user_upgraded(
        options[:user], 
        options[:from_plan], 
        options[:to_plan]
      )
    when 'trial_started'
      AdminNotification.notify_trial_started(options[:user])
    when 'trial_expired'
      AdminNotification.notify_trial_expired(options[:user])
    when 'payment_failed'
      AdminNotification.notify_payment_failed(
        options[:user], 
        options[:amount], 
        options[:error_message]
      )
    when 'high_response_volume'
      AdminNotification.notify_high_response_volume(
        options[:user], 
        options[:form], 
        options[:response_count]
      )
    when 'suspicious_activity'
      AdminNotification.notify_suspicious_activity(
        options[:user], 
        options[:activity_type], 
        options[:details]
      )
    else
      create_generic_notification
    end
  rescue => e
    Rails.logger.error "Failed to create admin notification: #{e.message}"
    nil
  end

  def create_generic_notification
    AdminNotification.create!(
      event_type: event_type.to_s,
      title: options[:title] || "System notification",
      message: options[:message] || "A system event occurred",
      user: options[:user],
      priority: options[:priority] || 'normal',
      category: options[:category] || 'system',
      metadata: options[:metadata] || {}
    )
  end

  def duplicate_notification_exists?
    # Prevent duplicate notifications for the same user and event within a short time
    return false unless options[:user]

    AdminNotification.where(
      event_type: event_type.to_s,
      user: options[:user],
      created_at: 5.minutes.ago..Time.current
    ).exists?
  end

  def broadcast_notification(notification)
    # Broadcast to admin dashboard using Turbo Streams
    Turbo::StreamsChannel.broadcast_prepend_to(
      "admin_notifications",
      target: "notifications-list",
      partial: "admin/notifications/notification",
      locals: { notification: notification }
    )

    # Update notification counter
    unread_count = AdminNotification.unread.count
    Turbo::StreamsChannel.broadcast_update_to(
      "admin_notifications",
      target: "notification-counter",
      html: unread_count > 0 ? unread_count.to_s : ""
    )
  end
end