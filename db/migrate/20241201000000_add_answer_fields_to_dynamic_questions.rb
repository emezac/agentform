class AddAnswerFieldsToDynamicQuestions < ActiveRecord::Migration[8.0]
  def change
    # Add the missing answered_at column
    add_column :dynamic_questions, :answered_at, :datetime, null: true
    
    # Add status to track question state
    add_column :dynamic_questions, :status, :string, default: 'pending', null: false
    
    # Add priority for ordering multiple dynamic questions
    add_column :dynamic_questions, :priority, :integer, default: 0
    
    # Add response quality tracking
    add_column :dynamic_questions, :response_quality_score, :decimal, precision: 5, scale: 2
    
    # Add indices for performance
    add_index :dynamic_questions, :answered_at
    add_index :dynamic_questions, :status
    add_index :dynamic_questions, [:form_response_id, :status]
    add_index :dynamic_questions, [:form_response_id, :answered_at]
  end
end