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
    
    # Only attempt broadcast if notification was successfully created
    if notification&.persisted?
      broadcast_notification(notification)
    end
    
    notification
  end

  private

  attr_reader :event_type, :options

  def should_notify?
    # Skip notifications in test environment unless explicitly enabled
    return false if Rails.env.test? && !options[:force_in_test]
    
    # Skip if event type is not valid
    return false unless AdminNotification::EVENT_TYPES.value?(event_type.to_s)
    
    # Skip duplicate notifications for certain events (with Redis error handling)
    return false if duplicate_notification_exists_safely?
    
    true
  end

  def duplicate_notification_exists_safely?
    return false unless options[:user]

    begin
      duplicate_notification_exists?
    rescue Redis::CannotConnectError, Redis::ConnectionError, Redis::TimeoutError => e
      Rails.logger.warn "Redis unavailable for notification validation: #{e.message}"
      Rails.logger.info "Proceeding with notification due to Redis connectivity issues"
      # Continue with notification creation when Redis is unavailable
      false
    end
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
  rescue Redis::CannotConnectError, Redis::ConnectionError, Redis::TimeoutError => e
    handle_redis_notification_error(e)
    nil
  rescue => e
    Rails.logger.error "Failed to create admin notification: #{e.message}"
    Rails.logger.error "Event type: #{event_type}, User ID: #{options[:user]&.id}"
    Rails.logger.error "Backtrace: #{e.backtrace.first(5).join("\n")}" if Rails.env.development?
    
    # Send to error tracking service if available
    if defined?(Sentry)
      Sentry.capture_exception(e, extra: {
        context: 'admin_notification_creation',
        event_type: event_type,
        user_id: options[:user]&.id,
        options: options.except(:user) # Exclude user object to avoid serialization issues
      })
    end
    
    nil
  end

  def handle_redis_notification_error(error)
    Rails.logger.warn "Redis unavailable during admin notification creation: #{error.message}"
    Rails.logger.info "Critical operation can continue, but notification creation failed due to Redis connectivity"
    
    # Log additional context for debugging
    Rails.logger.debug "Event type: #{event_type}"
    Rails.logger.debug "User ID: #{options[:user]&.id}"
    Rails.logger.debug "Redis URL: #{ENV['REDIS_URL']&.gsub(/:[^:@]*@/, ':***@')}"
    
    # Send to error tracking service if available
    if defined?(Sentry)
      Sentry.capture_exception(error, extra: {
        context: 'admin_notification_redis_failure',
        event_type: event_type,
        user_id: options[:user]&.id
      })
    end
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
    AdminNotification.where(
      event_type: event_type.to_s,
      user: options[:user],
      created_at: 5.minutes.ago..Time.current
    ).exists?
  end

  def broadcast_notification(notification)
    # Broadcast to admin dashboard using Turbo Streams with Redis error handling
    broadcast_with_redis_fallback do
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

  def broadcast_with_redis_fallback
    yield
  rescue Redis::CannotConnectError, Redis::ConnectionError, Redis::TimeoutError => e
    handle_redis_broadcast_error(e)
  rescue StandardError => e
    # Catch any other Redis-related errors that might not be explicitly Redis exceptions
    if redis_related_error?(e)
      handle_redis_broadcast_error(e)
    else
      raise e
    end
  end

  def handle_redis_broadcast_error(error)
    Rails.logger.warn "Redis unavailable for admin notification broadcast: #{error.message}"
    Rails.logger.info "Admin notification created successfully, but real-time broadcast skipped due to Redis connectivity"
    
    # Log additional context for debugging
    Rails.logger.debug "Redis URL: #{ENV['REDIS_URL']&.gsub(/:[^:@]*@/, ':***@')}"
    
    # Send to error tracking service if available, but don't re-raise
    if defined?(Sentry)
      Sentry.capture_exception(error, extra: {
        context: 'admin_notification_broadcast',
        service: self.class.name,
        event_type: @event_type,
        user_id: @options[:user]&.id
      })
    end
  end

  def redis_related_error?(error)
    # Check if the error message contains Redis-related keywords
    error.message.downcase.include?('redis') ||
    error.message.downcase.include?('connection') ||
    error.class.name.include?('Redis')
  end
end