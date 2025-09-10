class CreatePaymentAnalytics < ActiveRecord::Migration[8.0]
  def change
    create_table :payment_analytics, id: :uuid do |t|
      t.string :event_type, null: false
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :user_subscription_tier
      t.datetime :timestamp, null: false
      t.jsonb :context, null: false, default: {}
      t.string :session_id
      t.string :user_agent
      t.string :ip_address

      t.timestamps
    end

    add_index :payment_analytics, [:event_type, :timestamp]
    add_index :payment_analytics, [:user_id, :timestamp]
    add_index :payment_analytics, :user_subscription_tier
    add_index :payment_analytics, :session_id
    add_index :payment_analytics, :context, using: :gin
  end
end
