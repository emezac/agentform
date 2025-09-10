class AddDataIntegrityConstraints < ActiveRecord::Migration[8.0]
  def change
    # Add check constraints for discount codes
    add_check_constraint :discount_codes, 
                        "current_usage_count >= 0", 
                        name: "current_usage_count_non_negative"
    
    add_check_constraint :discount_codes, 
                        "max_usage_count IS NULL OR max_usage_count > 0", 
                        name: "max_usage_count_positive"
    
    add_check_constraint :discount_codes, 
                        "max_usage_count IS NULL OR current_usage_count <= max_usage_count", 
                        name: "current_usage_within_max"
    
    # Add check constraints for discount code usages
    add_check_constraint :discount_code_usages, 
                        "original_amount > 0", 
                        name: "original_amount_positive"
    
    add_check_constraint :discount_code_usages, 
                        "discount_amount > 0", 
                        name: "discount_amount_positive"
    
    add_check_constraint :discount_code_usages, 
                        "final_amount >= 0", 
                        name: "final_amount_non_negative"
    
    add_check_constraint :discount_code_usages, 
                        "discount_amount <= original_amount", 
                        name: "discount_not_greater_than_original"
    
    add_check_constraint :discount_code_usages, 
                        "final_amount = original_amount - discount_amount", 
                        name: "final_amount_calculation_correct"
    
    # Add check constraints for users
    add_check_constraint :users, 
                        "role IN ('user', 'admin', 'superadmin')", 
                        name: "valid_user_role"
    
    add_check_constraint :users, 
                        "subscription_tier IN ('basic', 'premium')", 
                        name: "valid_subscription_tier"
    
    add_check_constraint :users, 
                        "ai_credits_used >= 0", 
                        name: "ai_credits_used_non_negative"
    
    add_check_constraint :users, 
                        "monthly_ai_limit > 0", 
                        name: "monthly_ai_limit_positive"
    
    # Add check constraints for payment transactions
    add_check_constraint :payment_transactions, 
                        "amount > 0", 
                        name: "payment_amount_positive"
    
    add_check_constraint :payment_transactions, 
                        "status IN ('pending', 'processing', 'succeeded', 'failed', 'canceled')", 
                        name: "valid_payment_status"
    
    add_check_constraint :payment_transactions, 
                        "currency IN ('USD', 'EUR', 'GBP', 'CAD', 'AUD')", 
                        name: "valid_currency"
  end
end
