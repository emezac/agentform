module AdminHelper
  def admin_nav_class(path)
    base_classes = "text-sm font-medium transition-colors duration-200"
    
    if current_page?(path)
      "#{base_classes} text-red-600 border-b-2 border-red-600 pb-1"
    else
      "#{base_classes} text-gray-500 hover:text-gray-700"
    end
  end

  def admin_breadcrumbs
    breadcrumbs = [{ name: 'Admin', path: admin_dashboard_path }]
    
    case controller_name
    when 'dashboard'
      breadcrumbs << { name: 'Dashboard', path: nil }
    when 'users'
      breadcrumbs << { name: 'Users', path: admin_users_path }
      if action_name == 'show'
        breadcrumbs << { name: @user&.email || 'User Details', path: nil }
      elsif action_name == 'edit'
        breadcrumbs << { name: 'Edit User', path: nil }
      end
    when 'discount_codes'
      breadcrumbs << { name: 'Discount Codes', path: admin_discount_codes_path }
      if action_name == 'show'
        breadcrumbs << { name: @discount_code&.code || 'Code Details', path: nil }
      elsif action_name == 'edit'
        breadcrumbs << { name: 'Edit Code', path: nil }
      end
    when 'notifications'
      breadcrumbs << { name: 'Notifications', path: admin_notifications_path }
      if action_name == 'show'
        breadcrumbs << { name: 'Notification Details', path: nil }
      end
    when 'security'
      breadcrumbs << { name: 'Security', path: admin_security_index_path }
    when 'payment_analytics'
      breadcrumbs << { name: 'Payment Analytics', path: admin_payment_analytics_path }
    end
    
    breadcrumbs
  end

  def notification_priority_badge(notification)
    classes = case notification.priority
              when 'critical'
                'bg-red-100 text-red-800'
              when 'high'
                'bg-orange-100 text-orange-800'
              when 'normal'
                'bg-blue-100 text-blue-800'
              when 'low'
                'bg-gray-100 text-gray-800'
              else
                'bg-gray-100 text-gray-800'
              end

    content_tag :span, class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{classes}" do
      "#{notification.priority_icon} #{notification.priority.humanize}"
    end
  end

  def notification_event_badge(notification)
    content_tag :span, class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800" do
      "#{notification.event_icon} #{notification.event_type.humanize}"
    end
  end

  def notification_time_ago(notification)
    content_tag :span, class: "text-xs text-gray-500" do
      "#{time_ago_in_words(notification.created_at)} ago"
    end
  end

  def unread_notification_count
    @unread_count ||= AdminNotification.unread.count
  end

  def notification_counter_badge
    count = unread_notification_count
    return '' if count.zero?

    content_tag :span, count, 
      id: 'nav-notification-counter',
      class: "absolute -top-2 -right-2 inline-flex items-center justify-center px-2 py-1 text-xs font-bold leading-none text-white transform translate-x-1/2 -translate-y-1/2 bg-red-600 rounded-full"
  end

  def format_notification_metadata(metadata)
    return '' if metadata.blank?

    content_tag :div, class: "mt-2 text-xs text-gray-600" do
      metadata.map do |key, value|
        content_tag :div, class: "flex justify-between" do
          content_tag(:span, key.humanize + ':', class: "font-medium") +
          content_tag(:span, value.to_s, class: "ml-2")
        end
      end.join.html_safe
    end
  end

  def notification_stats_card(title, count, icon, color_class = 'bg-blue-500')
    content_tag :div, class: "bg-white overflow-hidden shadow rounded-lg" do
      content_tag :div, class: "p-5" do
        content_tag :div, class: "flex items-center" do
          content_tag(:div, class: "flex-shrink-0") do
            content_tag :div, class: "w-8 h-8 #{color_class} rounded-md flex items-center justify-center" do
              content_tag :span, icon, class: "text-white text-sm font-medium"
            end
          end +
          content_tag(:div, class: "ml-5 w-0 flex-1") do
            content_tag :dl do
              content_tag(:dt, title, class: "text-sm font-medium text-gray-500 truncate") +
              content_tag(:dd, count, class: "text-lg font-medium text-gray-900")
            end
          end
        end
      end
    end
  end
end