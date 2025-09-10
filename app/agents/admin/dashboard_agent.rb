class Admin::DashboardAgent < ApplicationAgent
  def get_dashboard_stats
    # Use caching service for better performance
    {
      user_stats: AdminCacheService.user_statistics,
      subscription_stats: get_subscription_statistics,
      discount_code_stats: AdminCacheService.discount_code_statistics,
      recent_activity: AdminCacheService.analytics_data('recent_activity'),
      quick_actions: get_quick_actions
    }
  end

  private

  def get_user_statistics
    # Use a single optimized query for all user statistics
    one_month_ago = 1.month.ago.strftime('%Y-%m-%d %H:%M:%S')
    
    stats = User.connection.select_one(<<~SQL)
      SELECT 
        COUNT(*) as total_users,
        COUNT(CASE WHEN suspended_at IS NULL THEN 1 END) as active_users,
        COUNT(CASE WHEN suspended_at IS NOT NULL THEN 1 END) as suspended_users,
        COUNT(CASE WHEN created_at >= '#{one_month_ago}' THEN 1 END) as new_users_this_month,
        COUNT(CASE WHEN subscription_tier = 'premium' THEN 1 END) as premium_users,
        COUNT(CASE WHEN subscription_tier = 'basic' THEN 1 END) as basic_users
      FROM users
    SQL

    total_users = stats['total_users'].to_i
    premium_users = stats['premium_users'].to_i

    {
      total: total_users,
      active: stats['active_users'].to_i,
      suspended: stats['suspended_users'].to_i,
      new_this_month: stats['new_users_this_month'].to_i,
      premium: premium_users,
      basic: stats['basic_users'].to_i,
      premium_percentage: total_users > 0 ? (premium_users.to_f / total_users * 100).round(1) : 0
    }
  end

  def get_subscription_statistics
    total_subscriptions = User.where(subscription_tier: 'premium').count
    active_subscriptions = User.where(subscription_tier: 'premium', suspended_at: nil).count
    
    # Calculate monthly recurring revenue (assuming $35/month for premium)
    mrr = active_subscriptions * 35
    
    # Get subscription growth this month
    new_subscriptions_this_month = User.where(
      subscription_tier: 'premium',
      created_at: 1.month.ago..Time.current
    ).count

    {
      total: total_subscriptions,
      active: active_subscriptions,
      mrr: mrr,
      new_this_month: new_subscriptions_this_month,
      conversion_rate: calculate_conversion_rate
    }
  end

  def get_discount_code_statistics
    # Use optimized queries with caching
    Rails.cache.fetch('admin_dashboard_discount_stats', expires_in: 5.minutes) do
      # Single query for discount code statistics
      code_stats = DiscountCode.connection.select_one(<<~SQL)
        SELECT 
          COUNT(*) as total_codes,
          COUNT(CASE WHEN active = true AND (expires_at IS NULL OR expires_at > NOW()) THEN 1 END) as active_codes,
          COUNT(CASE WHEN expires_at < NOW() THEN 1 END) as expired_codes,
          SUM(current_usage_count) as total_usage
        FROM discount_codes
      SQL

      # Single query for usage statistics
      usage_stats = DiscountCodeUsage.connection.select_one(<<~SQL)
        SELECT 
          SUM(discount_amount) as total_discount_amount,
          COUNT(*) as usage_count
        FROM discount_code_usages
      SQL

      # Get most popular discount code
      most_popular_code = DiscountCode.select('code, current_usage_count')
                                     .order(current_usage_count: :desc)
                                     .first

      total_usage = usage_stats['usage_count'].to_i
      total_discount_amount = usage_stats['total_discount_amount'].to_i

      {
        total_codes: code_stats['total_codes'].to_i,
        active_codes: code_stats['active_codes'].to_i,
        expired_codes: code_stats['expired_codes'].to_i,
        total_usage: total_usage,
        total_discount_amount: total_discount_amount,
        most_popular_code: most_popular_code&.code,
        average_discount_per_use: total_usage > 0 ? (total_discount_amount.to_f / total_usage).round(2) : 0
      }
    end
  end

  def get_recent_activity
    activities = []

    # Recent user registrations
    recent_users = User.order(created_at: :desc).limit(5)
    recent_users.each do |user|
      activities << {
        type: 'user_registration',
        message: "New user registered: #{user.email}",
        timestamp: user.created_at,
        icon: 'user-plus',
        color: 'text-green-600'
      }
    end

    # Recent discount code usage
    recent_usages = DiscountCodeUsage.includes(:user, :discount_code)
                                    .order(created_at: :desc)
                                    .limit(5)
    recent_usages.each do |usage|
      activities << {
        type: 'discount_usage',
        message: "Discount code '#{usage.discount_code.code}' used by #{usage.user.email}",
        timestamp: usage.created_at,
        icon: 'tag',
        color: 'text-purple-600'
      }
    end

    # Recent user suspensions
    recent_suspensions = User.where.not(suspended_at: nil)
                            .order(suspended_at: :desc)
                            .limit(3)
    recent_suspensions.each do |user|
      activities << {
        type: 'user_suspension',
        message: "User suspended: #{user.email} - #{user.suspended_reason}",
        timestamp: user.suspended_at,
        icon: 'user-x',
        color: 'text-red-600'
      }
    end

    # Sort all activities by timestamp and return the most recent 10
    activities.sort_by { |activity| activity[:timestamp] }.reverse.first(10)
  end

  def get_quick_actions
    [
      {
        title: 'Create Discount Code',
        description: 'Add a new promotional discount code',
        url: '/admin/discount_codes/new',
        icon: 'plus-circle',
        color: 'bg-purple-600 hover:bg-purple-700'
      },
      {
        title: 'Manage Users',
        description: 'View and manage user accounts',
        url: '/admin/users',
        icon: 'users',
        color: 'bg-indigo-600 hover:bg-indigo-700'
      },
      {
        title: 'View Discount Codes',
        description: 'Manage promotional codes',
        url: '/admin/discount_codes',
        icon: 'tag',
        color: 'bg-green-600 hover:bg-green-700'
      },
      {
        title: 'Export Data',
        description: 'Export user and usage data',
        url: '#',
        icon: 'download',
        color: 'bg-gray-600 hover:bg-gray-700'
      }
    ]
  end

  def calculate_conversion_rate
    total_users = User.count
    premium_users = User.where(subscription_tier: 'premium').count
    
    return 0 if total_users == 0
    
    (premium_users.to_f / total_users * 100).round(2)
  end
end