class AddEstimatedTimeMinutesToFormTemplates < ActiveRecord::Migration[8.0]
  def change
    add_column :form_templates, :estimated_time_minutes, :integer
  end
end
