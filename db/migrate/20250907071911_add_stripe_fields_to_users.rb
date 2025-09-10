class AddStripeFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :stripe_publishable_key, :text
    add_column :users, :stripe_secret_key, :text
    add_column :users, :stripe_webhook_secret, :text
    add_column :users, :stripe_account_id, :string
    add_column :users, :stripe_enabled, :boolean, default: false, null: false
    
    # Add indexes for performance
    add_index :users, :stripe_account_id
    add_index :users, :stripe_enabled
  end
end
