# frozen_string_literal: true

# Service for managing admin dashboard caching
class AdminCacheService < ApplicationService
  # Cache expiration times
  DASHBOARD_STATS_TTL = 5.minutes
  USER_STATS_TTL = 10.minutes
  DISCOUNT_STATS_TTL = 10.minutes
  ANALYTICS_TTL = 15.minutes

  class << self
    # Get or set dashboard statistics with caching
    def dashboard_stats
      Rails.cache.fetch('admin_dashboard_stats', expires_in: DASHBOARD_STATS_TTL) do
        calculate_dashboard_stats
      end
    end

    # Get or set user statistics with caching
    def user_statistics
      Rails.cache.fetch('admin_user_statistics', expires_in: USER_STATS_TTL) do
        calculate_user_statistics
      end
    end

    # Get or set discount code statistics with caching
    def discount_code_statistics
      Rails.cache.fetch('admin_discount_statistics', expires_in: DISCOUNT_STATS_TTL) do
        calculate_discount_statistics
      end
    end

    # Get or set analytics data with caching
    def analytics_data(type)
      cache_key = "admin_analytics_#{type}"
      Rails.cache.fetch(cache_key, expires_in: ANALYTICS_TTL) do
        case type
        when 'top_discount_codes'
          DiscountCode.most_used(10)
        when 'highest_revenue_codes'
          DiscountCode.highest_revenue_impact(10)
        when 'recent_activity'
          calculate_recent_activity
        else
          {}
        end
      end
    end

    # Clear all admin caches
    def clear_all_caches
      cache_keys = [
        'admin_dashboard_stats',
        'admin_user_statistics',
        'admin_discount_statistics',
        'admin_analytics_top_discount_codes',
        'admin_analytics_highest_revenue_codes',
        'admin_analytics_recent_activity',
        'discount_codes_dashboard_stats',
        'admin_discount_analytics',
        'admin_top_discount_codes',
        'admin_highest_revenue_codes',
        'admin_dashboard_discount_stats'
      ]

      cleared_count = 0
      cache_keys.each do |key|
        if Rails.cache.delete(key)
          cleared_count += 1
        end
      end

      Rails.logger.info "Cleared #{cleared_count} admin cache entries"
      cleared_count
    end

    # Clear specific cache type
    def clear_cache(type)
      case type
      when 'dashboard'
        Rails.cache.delete('admin_dashboard_stats')
      when 'users'
        Rails.cache.delete('admin_user_statistics')
      when 'discount_codes'
        Rails.cache.delete('admin_discount_statistics')
        Rails.cache.delete('discount_codes_dashboard_stats')
      when 'analytics'
        Rails.cache.delete_matched('admin_analytics_*')
      end
    end

    # Warm up caches (useful for scheduled jobs)
    def warm_up_caches
      Rails.logger.info "Warming up admin caches"
      
      # Pre-load dashboard stats
      dashboard_stats
      user_statistics
      discount_code_statistics
      
      # Pre-load analytics
      analytics_data('top_discount_codes')
      analytics_data('highest_revenue_codes')
      analytics_data('recent_activity')
      
      Rails.logger.info "Admin caches warmed up successfully"
    end

    private

    def calculate_dashboard_stats
      {
        users: calculate_user_statistics,
        discount_codes: calculate_discount_statistics,
        system: calculate_system_statistics,
        generated_at: Time.current
      }
    end

    def calculate_user_statistics
      # Use optimized single query for user statistics
      one_month_ago = 1.month.ago.strftime('%Y-%m-%d %H:%M:%S')
      one_week_ago = 1.week.ago.strftime('%Y-%m-%d %H:%M:%S')
      
      stats = User.connection.select_one(<<~SQL)
        SELECT 
          COUNT(*) as total_users,
          COUNT(CASE WHEN suspended_at IS NULL THEN 1 END) as active_users,
          COUNT(CASE WHEN suspended_at IS NOT NULL THEN 1 END) as suspended_users,
          COUNT(CASE WHEN created_at >= '#{one_month_ago}' THEN 1 END) as new_users_this_month,
          COUNT(CASE WHEN created_at >= '#{one_week_ago}' THEN 1 END) as new_users_this_week,
          COUNT(CASE WHEN subscription_tier = 'premium' THEN 1 END) as premium_users,
          COUNT(CASE WHEN subscription_tier = 'basic' THEN 1 END) as basic_users,
          COUNT(CASE WHEN role IN ('admin', 'superadmin') THEN 1 END) as admin_users
        FROM users
      SQL

      total_users = stats['total_users'].to_i
      premium_users = stats['premium_users'].to_i

      {
        total: total_users,
        active: stats['active_users'].to_i,
        suspended: stats['suspended_users'].to_i,
        new_this_month: stats['new_users_this_month'].to_i,
        new_this_week: stats['new_users_this_week'].to_i,
        premium: premium_users,
        basic: stats['basic_users'].to_i,
        admin: stats['admin_users'].to_i,
        premium_percentage: total_users > 0 ? (premium_users.to_f / total_users * 100).round(1) : 0
      }
    end

    def calculate_discount_statistics
      # Optimized queries for discount code statistics
      code_stats = DiscountCode.connection.select_one(<<~SQL)
        SELECT 
          COUNT(*) as total_codes,
          COUNT(CASE WHEN active = true AND (expires_at IS NULL OR expires_at > NOW()) THEN 1 END) as active_codes,
          COUNT(CASE WHEN expires_at < NOW() THEN 1 END) as expired_codes,
          SUM(current_usage_count) as total_usage,
          AVG(discount_percentage) as avg_discount_percentage
        FROM discount_codes
      SQL

      usage_stats = DiscountCodeUsage.connection.select_one(<<~SQL)
        SELECT 
          SUM(discount_amount) as total_discount_amount,
          COUNT(*) as usage_count,
          AVG(discount_amount) as avg_discount_amount
        FROM discount_code_usages
      SQL

      total_usage = usage_stats['usage_count'].to_i
      total_discount_amount = usage_stats['total_discount_amount'].to_i

      {
        total_codes: code_stats['total_codes'].to_i,
        active_codes: code_stats['active_codes'].to_i,
        expired_codes: code_stats['expired_codes'].to_i,
        total_usage: total_usage,
        total_discount_amount: total_discount_amount,
        average_discount_percentage: code_stats['avg_discount_percentage'].to_f.round(1),
        average_discount_per_use: total_usage > 0 ? (total_discount_amount.to_f / total_usage).round(2) : 0
      }
    end

    def calculate_system_statistics
      {
        total_forms: Form.count,
        total_responses: FormResponse.count,
        total_payments: PaymentTransaction.where(status: 'succeeded').count,
        cache_hit_rate: calculate_cache_hit_rate
      }
    end

    def calculate_recent_activity
      activities = []

      # Recent user registrations (last 10)
      User.order(created_at: :desc).limit(10).find_each do |user|
        activities << {
          type: 'user_registration',
          message: "New user registered: #{user.email}",
          timestamp: user.created_at,
          icon: 'user-plus',
          color: 'text-green-600'
        }
      end

      # Recent discount code usage (last 10)
      DiscountCodeUsage.includes(:user, :discount_code)
                      .order(created_at: :desc)
                      .limit(10)
                      .find_each do |usage|
        activities << {
          type: 'discount_usage',
          message: "Discount code '#{usage.discount_code.code}' used by #{usage.user.email}",
          timestamp: usage.created_at,
          icon: 'tag',
          color: 'text-purple-600'
        }
      end

      # Recent user suspensions (last 5)
      User.where.not(suspended_at: nil)
          .order(suspended_at: :desc)
          .limit(5)
          .find_each do |user|
        activities << {
          type: 'user_suspension',
          message: "User suspended: #{user.email}",
          timestamp: user.suspended_at,
          icon: 'user-x',
          color: 'text-red-600'
        }
      end

      # Sort by timestamp and return most recent 15
      activities.sort_by { |activity| activity[:timestamp] }.reverse.first(15)
    end

    def calculate_cache_hit_rate
      # This would require Redis monitoring in a real implementation
      # For now, return a placeholder
      85.0
    end
  end
end