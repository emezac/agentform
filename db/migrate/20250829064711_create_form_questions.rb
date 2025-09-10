class CreateFormQuestions < ActiveRecord::Migration[8.0]
  def change
    create_table :form_questions, id: :uuid do |t|
      # Form association
      t.references :form, null: false, foreign_key: true, type: :uuid
      
      # Question content
      t.string :title, null: false
      t.text :description
      t.string :question_type, null: false
      t.integer :position, null: false
      
      # Question configuration
      t.jsonb :question_config, default: {}
      t.jsonb :validation_rules, default: {}
      t.jsonb :display_options, default: {}
      
      # Conditional logic
      t.jsonb :conditional_logic, default: {}
      t.boolean :conditional_enabled, default: false
      
      # AI enhancement
      t.boolean :ai_enhanced, default: false
      t.jsonb :ai_config, default: {}
      t.text :ai_prompt
      
      # Question behavior
      t.boolean :required, default: false
      t.boolean :hidden, default: false
      t.boolean :readonly, default: false
      
      # Analytics
      t.integer :responses_count, default: 0
      t.integer :skip_count, default: 0
      t.decimal :completion_rate, precision: 5, scale: 2, default: 0.0
      
      # Metadata
      t.string :reference_id
      t.jsonb :metadata, default: {}

      t.timestamps null: false
    end

    # Indexes for performance (form_id index is automatically created by t.references)
    add_index :form_questions, [:form_id, :position]
    add_index :form_questions, :question_type
    add_index :form_questions, :required
    add_index :form_questions, :ai_enhanced
    add_index :form_questions, :conditional_enabled
    add_index :form_questions, :reference_id
    add_index :form_questions, [:form_id, :hidden]
  end
end
