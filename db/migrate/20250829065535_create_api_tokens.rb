class CreateApiTokens < ActiveRecord::Migration[8.0]
  def change
    create_table :api_tokens, id: :uuid do |t|
      # User association
      t.references :user, null: false, foreign_key: true, type: :uuid
      
      # Token identification
      t.string :name, null: false
      t.string :token, null: false, index: { unique: true }
      
      # Permissions and access control
      t.jsonb :permissions, default: {}
      t.boolean :active, default: true
      
      # Usage tracking
      t.datetime :last_used_at
      t.datetime :expires_at
      t.integer :usage_count, default: 0

      t.timestamps null: false
    end

    # Indexes for performance (user_id is auto-created by t.references, token has unique index)
    add_index :api_tokens, :active
    add_index :api_tokens, :expires_at
    add_index :api_tokens, [:user_id, :active]
    add_index :api_tokens, :last_used_at
  end
end
