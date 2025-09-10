class CreateDiscountCodeUsages < ActiveRecord::Migration[8.0]
  def change
    create_table :discount_code_usages, id: :uuid do |t|
      t.uuid :discount_code_id, null: false
      t.uuid :user_id, null: false
      t.string :subscription_id # Stripe subscription ID
      t.integer :original_amount, null: false # in cents
      t.integer :discount_amount, null: false # in cents
      t.integer :final_amount, null: false # in cents
      t.timestamp :used_at, null: false, default: -> { 'CURRENT_TIMESTAMP' }
      t.timestamps
    end

    add_index :discount_code_usages, :discount_code_id, name: 'idx_discount_usages_code'
    add_index :discount_code_usages, :user_id, name: 'idx_discount_usages_user'
    add_index :discount_code_usages, :user_id, unique: true, name: 'idx_one_discount_per_user'
    
    add_foreign_key :discount_code_usages, :discount_codes
    add_foreign_key :discount_code_usages, :users
  end
end
