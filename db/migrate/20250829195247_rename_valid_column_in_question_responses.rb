class RenameValidColumnInQuestionResponses < ActiveRecord::Migration[8.0]
  def change
    rename_column :question_responses, :valid, :answer_valid
  end
end
