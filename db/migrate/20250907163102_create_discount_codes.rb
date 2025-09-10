class CreateDiscountCodes < ActiveRecord::Migration[8.0]
  def change
    create_table :discount_codes, id: :uuid do |t|
      t.string :code, null: false, limit: 50
      t.integer :discount_percentage, null: false
      t.integer :max_usage_count
      t.integer :current_usage_count, default: 0, null: false
      t.timestamp :expires_at
      t.boolean :active, default: true, null: false
      t.uuid :created_by_id, null: false
      t.timestamps
    end

    add_index :discount_codes, 'LOWER(code)', unique: true, name: 'idx_discount_codes_code_unique'
    add_index :discount_codes, :active, name: 'idx_discount_codes_active'
    add_index :discount_codes, :expires_at, name: 'idx_discount_codes_expires_at'
    add_foreign_key :discount_codes, :users, column: :created_by_id
    
    add_check_constraint :discount_codes, 'discount_percentage BETWEEN 1 AND 99', name: 'discount_percentage_range'
  end
end
