class AddTemplateIdToForms < ActiveRecord::Migration[8.0]
  def change
    add_column :forms, :template_id, :uuid
  end
end
