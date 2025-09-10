# frozen_string_literal: true

# Concern for models that should invalidate admin caches when changed
module AdminCacheable
  extend ActiveSupport::Concern

  included do
    after_commit :invalidate_admin_caches, on: [:create, :update, :destroy]
  end

  private

  def invalidate_admin_caches
    # Determine which caches to clear based on the model
    case self.class.name
    when 'User'
      AdminCacheService.clear_cache('users')
      AdminCacheService.clear_cache('dashboard')
    when 'DiscountCode', 'DiscountCodeUsage'
      AdminCacheService.clear_cache('discount_codes')
      AdminCacheService.clear_cache('dashboard')
    when 'AuditLog'
      AdminCacheService.clear_cache('analytics')
    when 'PaymentTransaction'
      AdminCacheService.clear_cache('dashboard')
    end
    
    Rails.logger.debug "Invalidated admin caches for #{self.class.name} change"
  end
end