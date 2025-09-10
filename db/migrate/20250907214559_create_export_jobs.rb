class CreateExportJobs < ActiveRecord::Migration[8.0]
  def change
    create_table :export_jobs, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.references :form, null: false, foreign_key: true, type: :uuid
      t.string :job_id, null: false
      t.string :export_type, null: false # 'google_sheets', 'excel', etc.
      t.string :status, default: 'pending'
      t.json :configuration, default: {}
      t.string :spreadsheet_id
      t.string :spreadsheet_url
      t.integer :records_exported, default: 0
      t.json :error_details
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end

    add_index :export_jobs, [:user_id, :status]
    add_index :export_jobs, :job_id, unique: true
  end
end
