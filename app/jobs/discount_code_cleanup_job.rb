# frozen_string_literal: true

# Background job for cleaning up expired discount codes and maintaining data integrity
class DiscountCodeCleanupJob < ApplicationJob
  queue_as :default
  
  # Retry with exponential backoff
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform
    Rails.logger.info "Starting discount code cleanup job"
    
    cleanup_stats = {
      expired_codes_deactivated: 0,
      exhausted_codes_deactivated: 0,
      cache_keys_cleared: 0,
      errors: []
    }

    begin
      # Deactivate expired codes
      expired_count = deactivate_expired_codes
      cleanup_stats[:expired_codes_deactivated] = expired_count
      
      # Deactivate codes that have reached their usage limit
      exhausted_count = deactivate_exhausted_codes
      cleanup_stats[:exhausted_codes_deactivated] = exhausted_count
      
      # Clear related cache entries
      cache_cleared = clear_discount_code_caches
      cleanup_stats[:cache_keys_cleared] = cache_cleared
      
      # Log audit entry for cleanup
      AuditLog.create!(
        event_type: 'discount_code_cleanup',
        details: cleanup_stats.except(:errors),
        ip_address: 'system'
      )
      
      Rails.logger.info "Discount code cleanup completed: #{cleanup_stats}"
      
    rescue StandardError => e
      cleanup_stats[:errors] << e.message
      Rails.logger.error "Discount code cleanup failed: #{e.message}"
      
      # Log error audit entry
      AuditLog.create!(
        event_type: 'discount_code_cleanup_error',
        details: { error: e.message, backtrace: e.backtrace.first(5) },
        ip_address: 'system'
      )
      
      raise e
    end
    
    cleanup_stats
  end

  private

  def deactivate_expired_codes
    expired_codes = DiscountCode.where(active: true)
                               .where('expires_at < ?', Time.current)
    
    count = expired_codes.count
    return 0 if count.zero?
    
    expired_codes.update_all(
      active: false,
      updated_at: Time.current
    )
    
    Rails.logger.info "Deactivated #{count} expired discount codes"
    count
  end

  def deactivate_exhausted_codes
    exhausted_codes = DiscountCode.where(active: true)
                                 .where.not(max_usage_count: nil)
                                 .where('current_usage_count >= max_usage_count')
    
    count = exhausted_codes.count
    return 0 if count.zero?
    
    exhausted_codes.update_all(
      active: false,
      updated_at: Time.current
    )
    
    Rails.logger.info "Deactivated #{count} exhausted discount codes"
    count
  end

  def clear_discount_code_caches
    cache_keys = [
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
    
    Rails.logger.info "Cleared #{cleared_count} discount code cache entries"
    cleared_count
  end
end