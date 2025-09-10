class CreateQuestionResponses < ActiveRecord::Migration[8.0]
  def change
    create_table :question_responses, id: :uuid do |t|
      # Associations
      t.references :form_response, null: false, foreign_key: true, type: :uuid
      t.references :form_question, null: false, foreign_key: true, type: :uuid
      
      # Response data
      t.text :answer_text
      t.jsonb :answer_data, default: {}
      t.jsonb :processed_answer, default: {}
      
      # Response metadata
      t.integer :time_spent_seconds, default: 0
      t.integer :revision_count, default: 0
      t.boolean :skipped, default: false
      t.string :skip_reason
      
      # AI analysis for this specific answer
      t.jsonb :ai_analysis, default: {}
      t.decimal :ai_confidence, precision: 5, scale: 2
      t.text :ai_insights
      
      # Validation and quality
      t.boolean :valid, default: true
      t.jsonb :validation_errors, default: {}
      t.decimal :quality_score, precision: 5, scale: 2
      
      # Behavioral data
      t.integer :focus_time_seconds, default: 0
      t.integer :blur_count, default: 0
      t.integer :keystroke_count, default: 0
      t.jsonb :interaction_data, default: {}
      
      # Follow-up and dynamic questions
      t.boolean :triggered_followup, default: false
      t.jsonb :followup_config, default: {}

      t.timestamps null: false
    end

    # Indexes for performance (avoiding duplicate indexes from references)
    add_index :question_responses, [:form_response_id, :form_question_id], 
              unique: true, name: 'idx_question_responses_unique'
    add_index :question_responses, :skipped
    add_index :question_responses, :valid
    add_index :question_responses, :triggered_followup
    add_index :question_responses, :created_at
  end
end
