class CreateGoogleIntegrations < ActiveRecord::Migration[8.0]
  def change
    create_table :google_integrations, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :access_token, null: false
      t.string :refresh_token, null: false
      t.datetime :token_expires_at, null: false
      t.string :scope, null: false
      t.json :user_info # Email, nombre, etc.
      t.boolean :active, default: true
      t.datetime :last_used_at
      t.integer :usage_count, default: 0
      t.json :error_log, default: []

      t.timestamps
    end

    add_index :google_integrations, [:user_id, :active]
    add_index :google_integrations, :token_expires_at
  end
end
