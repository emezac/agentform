class AddSubscriptionTierToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :subscription_tier, :string, default: 'basic', null: false
    
    # Update existing users to basic (freemium plan deprecated)
    User.where(subscription_tier: nil).update_all(subscription_tier: 'basic')
    
    # Update premium users based on role
    User.where(role: 'premium').update_all(subscription_tier: 'premium')
  end
end