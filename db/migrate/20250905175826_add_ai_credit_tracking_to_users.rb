class AddAiCreditTrackingToUsers < ActiveRecord::Migration[8.0]
  def change
    # Change ai_credits_used from integer to decimal
    change_column :users, :ai_credits_used, :decimal, precision: 10, scale: 4, default: 0.0
    
    # Rename ai_credits_limit to monthly_ai_limit and change to decimal
    rename_column :users, :ai_credits_limit, :monthly_ai_limit
    change_column :users, :monthly_ai_limit, :decimal, precision: 10, scale: 4, default: 10.0
    
    # Add indexes for AI-related queries and performance optimization
    add_index :users, :ai_credits_used
    add_index :users, :monthly_ai_limit
    add_index :users, [:ai_credits_used, :monthly_ai_limit], name: 'index_users_on_ai_credits'
  end
end
