# frozen_string_literal: true

# Scheduled job for admin system maintenance tasks
class AdminMaintenanceJob < ApplicationJob
  queue_as :default
  
  # Run with lower priority to avoid impacting user-facing operations
  retry_on StandardError, wait: :exponentially_longer, attempts: 2

  def perform(task_type = 'full')
    Rails.logger.info "Starting admin maintenance job: #{task_type}"
    
    maintenance_stats = {
      task_type: task_type,
      started_at: Time.current,
      completed_tasks: [],
      errors: []
    }

    begin
      case task_type
      when 'full'
        run_full_maintenance(maintenance_stats)
      when 'cleanup'
        run_cleanup_only(maintenance_stats)
      when 'cache_warmup'
        run_cache_warmup_only(maintenance_stats)
      else
        raise ArgumentError, "Unknown maintenance task type: #{task_type}"
      end

      maintenance_stats[:completed_at] = Time.current
      maintenance_stats[:duration_seconds] = (maintenance_stats[:completed_at] - maintenance_stats[:started_at]).round(2)
      
      # Log successful maintenance
      AuditLog.create!(
        event_type: 'admin_maintenance_completed',
        details: maintenance_stats.except(:errors),
        ip_address: 'system'
      )
      
      Rails.logger.info "Admin maintenance completed: #{maintenance_stats}"
      
    rescue StandardError => e
      maintenance_stats[:errors] << e.message
      maintenance_stats[:failed_at] = Time.current
      
      Rails.logger.error "Admin maintenance failed: #{e.message}"
      
      # Log maintenance failure
      AuditLog.create!(
        event_type: 'admin_maintenance_failed',
        details: maintenance_stats,
        ip_address: 'system'
      )
      
      raise e
    end
    
    maintenance_stats
  end

  private

  def run_full_maintenance(stats)
    # Run discount code cleanup
    cleanup_result = DiscountCodeCleanupJob.perform_now
    stats[:completed_tasks] << {
      task: 'discount_code_cleanup',
      result: cleanup_result
    }
    
    # Clear old audit logs (keep last 6 months)
    old_logs_count = cleanup_old_audit_logs
    stats[:completed_tasks] << {
      task: 'audit_log_cleanup',
      old_logs_removed: old_logs_count
    }
    
    # Clear and warm up caches
    cache_result = refresh_admin_caches
    stats[:completed_tasks] << {
      task: 'cache_refresh',
      result: cache_result
    }
    
    # Update user statistics (for users who haven't been active)
    inactive_users_updated = update_inactive_user_stats
    stats[:completed_tasks] << {
      task: 'user_stats_update',
      users_updated: inactive_users_updated
    }
  end

  def run_cleanup_only(stats)
    cleanup_result = DiscountCodeCleanupJob.perform_now
    stats[:completed_tasks] << {
      task: 'discount_code_cleanup',
      result: cleanup_result
    }
    
    old_logs_count = cleanup_old_audit_logs
    stats[:completed_tasks] << {
      task: 'audit_log_cleanup',
      old_logs_removed: old_logs_count
    }
  end

  def run_cache_warmup_only(stats)
    cache_result = refresh_admin_caches
    stats[:completed_tasks] << {
      task: 'cache_refresh',
      result: cache_result
    }
  end

  def cleanup_old_audit_logs
    # Remove audit logs older than 6 months
    cutoff_date = 6.months.ago
    old_logs = AuditLog.where('created_at < ?', cutoff_date)
    count = old_logs.count
    
    if count > 0
      old_logs.delete_all
      Rails.logger.info "Removed #{count} old audit log entries"
    end
    
    count
  end

  def refresh_admin_caches
    # Clear all admin caches
    cleared_count = AdminCacheService.clear_all_caches
    
    # Warm up caches with fresh data
    AdminCacheService.warm_up_caches
    
    {
      caches_cleared: cleared_count,
      caches_warmed: true
    }
  end

  def update_inactive_user_stats
    # Update last_activity_at for users who haven't been updated recently
    # This helps with admin dashboard accuracy
    inactive_cutoff = 1.week.ago
    inactive_users = User.where('last_activity_at < ? OR last_activity_at IS NULL', inactive_cutoff)
    
    count = inactive_users.count
    if count > 0
      # Update in batches to avoid long-running queries
      inactive_users.find_in_batches(batch_size: 100) do |batch|
        batch.each do |user|
          # Check if user has recent forms or responses
          recent_activity = user.forms.where('created_at > ?', inactive_cutoff).exists? ||
                           user.form_responses.where('created_at > ?', inactive_cutoff).exists?
          
          if recent_activity
            user.update_column(:last_activity_at, Time.current)
          end
        end
      end
    end
    
    count
  end
end