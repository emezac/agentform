# frozen_string_literal: true

class DeviseCreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users, id: :uuid do |t|
      ## Database authenticatable
      t.string :email,              null: false, default: ""
      t.string :encrypted_password, null: false, default: ""

      ## Recoverable
      t.string   :reset_password_token
      t.datetime :reset_password_sent_at

      ## Rememberable
      t.datetime :remember_created_at

      ## Trackable
      t.integer  :sign_in_count, default: 0, null: false
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string   :current_sign_in_ip
      t.string   :last_sign_in_ip

      ## Confirmable
      t.string   :confirmation_token
      t.datetime :confirmed_at
      t.datetime :confirmation_sent_at
      t.string   :unconfirmed_email # Only if using reconfirmable

      ## AgentForm specific fields
      t.string :first_name
      t.string :last_name
      t.string :role, null: false, default: 'user'
      
      # User preferences stored as JSONB for flexibility
      t.jsonb :preferences, default: {}
      
      # AI-related settings
      t.jsonb :ai_settings, default: {}
      t.integer :ai_credits_used, default: 0
      t.integer :ai_credits_limit, default: 1000
      
      # Subscription and billing
      t.string :subscription_status, default: 'free'
      t.datetime :subscription_expires_at
      t.string :stripe_customer_id
      
      # Account status
      t.boolean :active, default: true
      t.datetime :last_activity_at
      
      # Onboarding
      t.boolean :onboarding_completed, default: false
      t.jsonb :onboarding_progress, default: {}

      t.timestamps null: false
    end

    add_index :users, :email,                unique: true
    add_index :users, :reset_password_token, unique: true
    add_index :users, :confirmation_token,   unique: true
    add_index :users, :role
    add_index :users, :subscription_status
    add_index :users, :active
    add_index :users, :last_activity_at
    add_index :users, :stripe_customer_id, unique: true
  end
end
