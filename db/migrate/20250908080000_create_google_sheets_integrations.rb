class CreateGoogleSheetsIntegrations < ActiveRecord::Migration[7.1]
  def change
    # Check if table already exists to avoid conflicts
    unless table_exists?(:google_sheets_integrations)
      create_table :google_sheets_integrations, id: :uuid do |t|
        t.references :form, null: false, foreign_key: true, type: :uuid
        t.string :spreadsheet_id, null: false
        t.string :sheet_name, default: 'Responses'
        t.boolean :auto_sync, default: false
        t.datetime :last_sync_at
        t.json :field_mapping, default: {}
        t.boolean :active, default: true
        t.text :error_message
        t.integer :sync_count, default: 0
        
        t.timestamps
      end

      add_index :google_sheets_integrations, :form_id unless index_exists?(:google_sheets_integrations, :form_id)
      add_index :google_sheets_integrations, :spreadsheet_id unless index_exists?(:google_sheets_integrations, :spreadsheet_id)
    end
  end
end