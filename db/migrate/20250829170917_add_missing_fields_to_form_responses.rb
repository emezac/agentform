class AddMissingFieldsToFormResponses < ActiveRecord::Migration[8.0]
  def change
    add_column :form_responses, :last_activity_at, :datetime
    add_column :form_responses, :abandoned_at, :datetime
    add_column :form_responses, :abandonment_reason, :string
    add_column :form_responses, :paused_at, :datetime
    add_column :form_responses, :resumed_at, :datetime
    add_column :form_responses, :completion_data, :jsonb
    add_column :form_responses, :draft_data, :jsonb
    add_column :form_responses, :quality_score, :decimal
    add_column :form_responses, :sentiment_score, :decimal
  end
end
