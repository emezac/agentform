class CreateFormTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :form_templates, id: :uuid do |t|
      # Template identification
      t.string :name, null: false
      t.text :description
      t.string :category, null: false
      t.string :visibility, default: 'public'
      
      # Creator association (optional - system templates have no creator)
      t.references :creator, null: true, foreign_key: { to_table: :users }, type: :uuid
      
      # Template content and configuration
      t.jsonb :template_data, null: false
      t.jsonb :preview_data, default: {}
      
      # Usage and rating metrics
      t.integer :usage_count, default: 0
      t.decimal :rating, precision: 3, scale: 2
      t.integer :reviews_count, default: 0

      t.timestamps null: false
    end

    # Indexes for performance (creator_id is auto-created by t.references)
    add_index :form_templates, :category
    add_index :form_templates, :visibility
    add_index :form_templates, [:category, :visibility]
    add_index :form_templates, :usage_count
    add_index :form_templates, :rating
  end
end
