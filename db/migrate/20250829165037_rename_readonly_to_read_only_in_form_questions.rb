class RenameReadonlyToReadOnlyInFormQuestions < ActiveRecord::Migration[8.0]
  def change
    rename_column :form_questions, :readonly, :read_only
  end
end
