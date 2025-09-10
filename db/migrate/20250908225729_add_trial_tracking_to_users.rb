class AddTrialTrackingToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :trial_ends_at, :datetime
    add_index :users, :trial_ends_at
    
    # Backfill existing users with trialing status
    reversible do |dir|
      dir.up do
        # Get trial period from environment or use default
        trial_days = ENV['TRIAL_PERIOD_DAYS']&.to_i || 14
        
        if trial_days > 0
          # Update existing users with trialing status
          execute <<~SQL
            UPDATE users 
            SET trial_ends_at = created_at + INTERVAL '#{trial_days} days'
            WHERE subscription_status = 'trialing' 
            AND trial_ends_at IS NULL
          SQL
          
          puts "Updated users with trialing status to have trial_ends_at set to #{trial_days} days from creation"
        end
      end
    end
  end
end
