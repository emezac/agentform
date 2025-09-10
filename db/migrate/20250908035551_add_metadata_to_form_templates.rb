class AddMetadataToFormTemplates < ActiveRecord::Migration[8.0]
  def change
    add_column :form_templates, :metadata, :jsonb, default: {}
    add_index :form_templates, :metadata, using: :gin
  end
end
