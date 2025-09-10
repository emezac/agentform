class CreateAnalysisReports < ActiveRecord::Migration[8.0]
  def change
    create_table :analysis_reports, id: :uuid do |t|
      t.references :form_response, null: false, foreign_key: true, type: :uuid
      t.string :report_type, null: false # 'comprehensive_strategic_analysis', 'technical_assessment', etc.
      t.text :markdown_content, null: false
      t.json :metadata # AI models used, cost, sections included, etc.
      t.string :status, default: 'generating' # generating, completed, failed
      t.string :file_path # Path to downloadable file
      t.integer :file_size
      t.decimal :ai_cost, precision: 10, scale: 4
      t.datetime :generated_at
      t.datetime :expires_at # For cleanup of old reports

      t.timestamps
    end

    add_index :analysis_reports, :report_type
    add_index :analysis_reports, :status
    add_index :analysis_reports, :generated_at
  end
end