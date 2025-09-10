class AddAnsweredAtToDynamicQuestions < ActiveRecord::Migration[8.0]
  def change
    add_column :dynamic_questions, :answered_at, :datetime, null: true
    
    add_index :dynamic_questions, :answered_at
  end
end
