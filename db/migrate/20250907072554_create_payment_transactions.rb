class CreatePaymentTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :payment_transactions, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.references :form, null: false, foreign_key: true, type: :uuid
      t.references :form_response, null: false, foreign_key: true, type: :uuid
      t.string :stripe_payment_intent_id, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :currency, limit: 3, null: false, default: 'USD'
      t.string :status, null: false, default: 'pending'
      t.string :payment_method, null: false
      t.json :metadata, default: {}
      t.text :failure_reason
      t.datetime :processed_at

      t.timestamps
    end
    
    # Add indexes for performance
    add_index :payment_transactions, :stripe_payment_intent_id, unique: true
    add_index :payment_transactions, :status
    add_index :payment_transactions, :processed_at
    add_index :payment_transactions, [:user_id, :created_at]
    add_index :payment_transactions, [:form_id, :status]
  end
end
