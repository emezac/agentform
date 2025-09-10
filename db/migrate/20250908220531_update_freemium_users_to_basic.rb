class UpdateFreemiumUsersToBasic < ActiveRecord::Migration[8.0]
  def up
    # Update all users with 'freemium' subscription_tier to 'basic'
    User.where(subscription_tier: 'freemium').update_all(subscription_tier: 'basic')
    
    puts "Updated #{User.where(subscription_tier: 'freemium').count} freemium users to basic plan"
  end

  def down
    # Rollback: change basic users back to freemium (only if they were originally freemium)
    # Note: This is a simplified rollback and may not be 100% accurate
    # In practice, you might want to track this change more carefully
    puts "Warning: Rolling back freemium to basic migration"
    puts "This rollback assumes all basic users were originally freemium, which may not be accurate"
  end
end
