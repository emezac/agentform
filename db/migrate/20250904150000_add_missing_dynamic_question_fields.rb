class AddMissingDynamicQuestionFields < ActiveRecord::Migration[8.0]
  def change
    # Add status to track question state (only if it doesn't exist)
    unless column_exists?(:dynamic_questions, :status)
      add_column :dynamic_questions, :status, :string, default: 'pending', null: false
    end
    
    # Add priority for ordering multiple dynamic questions (only if it doesn't exist)
    unless column_exists?(:dynamic_questions, :priority)
      add_column :dynamic_questions, :priority, :integer, default: 0
    end
    
    # Add response quality tracking (only if it doesn't exist)
    unless column_exists?(:dynamic_questions, :response_quality_score)
      add_column :dynamic_questions, :response_quality_score, :decimal, precision: 5, scale: 2
    end
    
    # Add missing indices (only if they don't exist)
    unless index_exists?(:dynamic_questions, :status)
      add_index :dynamic_questions, :status
    end
    
    unless index_exists?(:dynamic_questions, [:form_response_id, :status])
      add_index :dynamic_questions, [:form_response_id, :status]
    end
    
    unless index_exists?(:dynamic_questions, [:form_response_id, :answered_at])
      add_index :dynamic_questions, [:form_response_id, :answered_at]
    end
  end
end