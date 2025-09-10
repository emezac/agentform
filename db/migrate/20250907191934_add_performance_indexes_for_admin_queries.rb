class AddPerformanceIndexesForAdminQueries < ActiveRecord::Migration[8.0]
  def change
    # Indexes for admin user management queries
    add_index :users, [:role, :created_at], name: 'idx_users_role_created_at'
    add_index :users, [:subscription_tier, :created_at], name: 'idx_users_tier_created_at'
    add_index :users, [:suspended_at, :created_at], name: 'idx_users_suspended_created_at'
    add_index :users, [:email, :first_name, :last_name], name: 'idx_users_search_fields'
    
    # Composite index for user listing with common filters
    add_index :users, [:role, :subscription_tier, :suspended_at, :created_at], 
              name: 'idx_users_admin_filters'
    
    # Indexes for discount code admin queries
    add_index :discount_codes, [:active, :created_at], name: 'idx_discount_codes_active_created_at'
    add_index :discount_codes, [:current_usage_count, :max_usage_count], 
              name: 'idx_discount_codes_usage_tracking'
    
    # Composite index for discount code analytics
    add_index :discount_codes, [:active, :expires_at, :current_usage_count], 
              name: 'idx_discount_codes_analytics'
    
    # Indexes for discount code usage analytics
    add_index :discount_code_usages, [:used_at, :discount_amount], 
              name: 'idx_discount_usages_analytics'
    add_index :discount_code_usages, [:discount_code_id, :used_at], 
              name: 'idx_discount_usages_code_timeline'
    
    # Indexes for audit log queries (admin monitoring)
    add_index :audit_logs, [:event_type, :user_id, :created_at], 
              name: 'idx_audit_logs_admin_monitoring'
    
    # Indexes for payment transaction analytics
    add_index :payment_transactions, [:status, :processed_at], 
              name: 'idx_payment_transactions_status_processed'
    add_index :payment_transactions, [:user_id, :status, :processed_at], 
              name: 'idx_payment_transactions_user_analytics'
    
    # Partial indexes for active records (better performance for common queries)
    add_index :users, [:created_at], 
              where: "suspended_at IS NULL", 
              name: 'idx_users_active_created_at'
    
    add_index :discount_codes, [:expires_at], 
              where: "active = true AND expires_at IS NOT NULL", 
              name: 'idx_discount_codes_active_expiring'
    
    # Index for dashboard statistics queries
    add_index :users, [:subscription_tier, :suspended_at, :created_at], 
              name: 'idx_users_dashboard_stats'
  end
end
