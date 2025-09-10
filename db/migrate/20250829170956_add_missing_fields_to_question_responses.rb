class AddMissingFieldsToQuestionResponses < ActiveRecord::Migration[8.0]
  def change
    add_column :question_responses, :ai_analysis_results, :jsonb
    add_column :question_responses, :ai_analysis_requested_at, :datetime
    add_column :question_responses, :response_time_ms, :integer
  end
end
