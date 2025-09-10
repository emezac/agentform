class CreateDynamicQuestions < ActiveRecord::Migration[8.0]
  def change
    create_table :dynamic_questions, id: :uuid do |t|
      # Form response association (required)
      t.references :form_response, null: false, foreign_key: true, type: :uuid
      
      # Optional reference to the original question that generated this dynamic question
      t.references :generated_from_question, null: true, 
                   foreign_key: { to_table: :form_questions }, type: :uuid
      
      # Question definition
      t.string :question_type, null: false
      t.text :title, null: false
      t.text :description
      
      # Question configuration and options
      t.jsonb :configuration, default: {}
      
      # AI generation metadata
      t.jsonb :generation_context, default: {}
      t.text :generation_prompt
      t.string :generation_model
      
      # Response data (when answered)
      t.jsonb :answer_data, default: {}
      
      # Performance metrics
      t.decimal :response_time_ms, precision: 8, scale: 2
      t.decimal :ai_confidence, precision: 5, scale: 2

      t.timestamps null: false
    end

    # Indexes for performance (form_response_id and generated_from_question_id are auto-created by t.references)
    add_index :dynamic_questions, :question_type
    add_index :dynamic_questions, [:form_response_id, :question_type]
    add_index :dynamic_questions, :created_at
  end
end
