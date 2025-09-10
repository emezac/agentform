class AddDiscountFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :discount_code_used, :boolean, default: false, null: false
    add_column :users, :suspended_at, :timestamp
    add_column :users, :suspended_reason, :text
    
    add_index :users, :discount_code_used
    add_index :users, :suspended_at
  end
end
