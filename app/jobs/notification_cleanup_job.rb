class NotificationCleanupJob < ApplicationJob
  queue_as :default

  # Keep notifications for 90 days by default
  RETENTION_PERIOD = 90.days

  def perform(retention_period: RETENTION_PERIOD)
    cleanup_old_notifications(retention_period)
    log_cleanup_stats
  end

  private

  def cleanup_old_notifications(retention_period)
    cutoff_date = retention_period.ago
    
    @deleted_count = AdminNotification.where('created_at < ?', cutoff_date).delete_all
    
    Rails.logger.info "Cleaned up #{@deleted_count} old admin notifications (older than #{retention_period.inspect})"
  end

  def log_cleanup_stats
    remaining_count = AdminNotification.count
    unread_count = AdminNotification.unread.count
    
    Rails.logger.info "Notification cleanup completed:"
    Rails.logger.info "- Deleted: #{@deleted_count} notifications"
    Rails.logger.info "- Remaining: #{remaining_count} notifications"
    Rails.logger.info "- Unread: #{unread_count} notifications"

    # Create a system notification about the cleanup
    if @deleted_count > 0
      AdminNotification.create!(
        event_type: 'system',
        title: 'Notification cleanup completed',
        message: "Cleaned up #{@deleted_count} old notifications. #{remaining_count} notifications remaining.",
        priority: 'low',
        category: 'system',
        metadata: {
          deleted_count: @deleted_count,
          remaining_count: remaining_count,
          unread_count: unread_count,
          cleanup_date: Time.current
        }
      )
    end
  end
end