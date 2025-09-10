class FixSubscriptionTierConstraints < ActiveRecord::Migration[8.0]
  def up
    # Remove the old constraint
    remove_check_constraint :users, name: "valid_subscription_tier"
    
    # Update default value from 'freemium' to 'basic'
    change_column_default :users, :subscription_tier, from: 'freemium', to: 'basic'
    
    # Update any remaining freemium users to basic
    User.where(subscription_tier: 'freemium').update_all(subscription_tier: 'basic')
    
    # Add new constraint that only allows 'basic' and 'premium'
    add_check_constraint :users, 
                        "subscription_tier IN ('basic', 'premium')", 
                        name: "valid_subscription_tier"
    
    puts "Updated subscription_tier constraints and defaults"
  end

  def down
    # Remove the new constraint
    remove_check_constraint :users, name: "valid_subscription_tier"
    
    # Restore old default
    change_column_default :users, :subscription_tier, from: 'basic', to: 'freemium'
    
    # Add old constraint
    add_check_constraint :users, 
                        "subscription_tier IN ('freemium', 'basic', 'premium')", 
                        name: "valid_subscription_tier"
  end
end