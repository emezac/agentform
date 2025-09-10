class CreateForms < ActiveRecord::Migration[8.0]
  def change
    create_table :forms, id: :uuid do |t|
      # Basic form information
      t.string :name, null: false
      t.text :description
      t.string :status, null: false, default: 'draft'
      t.string :category, default: 'general'
      
      # Unique sharing token for public access
      t.string :share_token, null: false
      t.boolean :public, default: false
      
      # User association
      t.references :user, null: false, foreign_key: true, type: :uuid
      
      # Configuration fields stored as JSONB for flexibility
      t.jsonb :form_settings, default: {}
      t.jsonb :ai_configuration, default: {}
      t.jsonb :style_configuration, default: {}
      t.jsonb :integration_settings, default: {}
      t.jsonb :notification_settings, default: {}
      
      # Analytics and performance
      t.integer :views_count, default: 0
      t.integer :responses_count, default: 0
      t.integer :completion_count, default: 0
      t.decimal :completion_rate, precision: 5, scale: 2, default: 0.0
      
      # Publishing and scheduling
      t.datetime :published_at
      t.datetime :expires_at
      t.boolean :accepts_responses, default: true
      
      # AI and workflow settings
      t.boolean :ai_enabled, default: false
      t.string :workflow_class
      t.jsonb :workflow_config, default: {}
      
      # Branding and customization
      t.boolean :show_branding, default: true
      t.string :custom_domain
      t.string :redirect_url
      
      # Security and access control
      t.boolean :requires_login, default: false
      t.string :password_hash
      t.jsonb :access_restrictions, default: {}

      t.timestamps null: false
    end

    # Indexes for performance (user_id index is automatically created by t.references)
    add_index :forms, :share_token, unique: true
    add_index :forms, :status
    add_index :forms, :category
    add_index :forms, :public
    add_index :forms, :published_at
    add_index :forms, :expires_at
    add_index :forms, :ai_enabled
    add_index :forms, :custom_domain, unique: true
    add_index :forms, [:user_id, :status]
    add_index :forms, [:public, :status]
  end
end
