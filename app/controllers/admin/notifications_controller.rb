class Admin::NotificationsController < Admin::BaseController
  before_action :set_notification, only: [:show, :mark_as_read, :destroy]

  def index
    @notifications = AdminNotification.includes(:user)
                                    .recent
                                    .page(params[:page])
                                    .per(20)

    # Apply filters
    @notifications = @notifications.by_event_type(params[:event_type]) if params[:event_type].present?
    @notifications = @notifications.by_priority(params[:priority]) if params[:priority].present?
    @notifications = @notifications.unread if params[:status] == 'unread'
    @notifications = @notifications.read if params[:status] == 'read'

    # Stats for dashboard
    @stats = {
      total: AdminNotification.count,
      unread: AdminNotification.unread.count,
      today: AdminNotification.today.count,
      this_week: AdminNotification.this_week.count,
      critical: AdminNotification.by_priority('critical').unread.count
    }

    # Event type counts for filters
    @event_type_counts = AdminNotification.group(:event_type).count
    @priority_counts = AdminNotification.group(:priority).count

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def show
    @notification.mark_as_read! if @notification.unread?
  end

  def mark_as_read
    @notification.mark_as_read!
    
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("notification_#{@notification.id}", 
            partial: "admin/notifications/notification", 
            locals: { notification: @notification }
          ),
          turbo_stream.update("notification-counter", 
            AdminNotification.unread.count > 0 ? AdminNotification.unread.count.to_s : ""
          )
        ]
      end
      format.json { head :ok }
    end
  end

  def mark_all_as_read
    AdminNotification.unread.update_all(read_at: Time.current)
    
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("notifications-list", 
            partial: "admin/notifications/notifications_list", 
            locals: { notifications: AdminNotification.recent.limit(20) }
          ),
          turbo_stream.update("notification-counter", "")
        ]
      end
      format.json { head :ok }
    end
  end

  def destroy
    @notification.destroy
    
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove("notification_#{@notification.id}"),
          turbo_stream.update("notification-counter", 
            AdminNotification.unread.count > 0 ? AdminNotification.unread.count.to_s : ""
          )
        ]
      end
      format.json { head :ok }
    end
  end

  def stats
    @daily_stats = AdminNotification
      .where(created_at: 30.days.ago..Time.current)
      .group_by_day(:created_at)
      .group(:event_type)
      .count

    @priority_distribution = AdminNotification
      .where(created_at: 7.days.ago..Time.current)
      .group(:priority)
      .count

    @user_activity = AdminNotification
      .joins(:user)
      .where(created_at: 7.days.ago..Time.current)
      .group("users.subscription_tier")
      .count

    respond_to do |format|
      format.json do
        render json: {
          daily_stats: @daily_stats,
          priority_distribution: @priority_distribution,
          user_activity: @user_activity
        }
      end
    end
  end

  private

  def set_notification
    @notification = AdminNotification.find(params[:id])
  end
end