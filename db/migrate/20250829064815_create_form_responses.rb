class CreateFormResponses < ActiveRecord::Migration[8.0]
  def change
    create_table :form_responses, id: :uuid do |t|
      # Form association
      t.references :form, null: false, foreign_key: true, type: :uuid
      
      # Optional user association (for logged-in users)
      t.references :user, null: true, foreign_key: true, type: :uuid
      
      # Response identification
      t.string :session_id
      t.string :fingerprint
      t.inet :ip_address
      t.string :user_agent
      
      # Response status and progress
      t.string :status, null: false, default: 'in_progress'
      t.integer :current_question_position, default: 1
      t.decimal :progress_percentage, precision: 5, scale: 2, default: 0.0
      
      # Timing information
      t.datetime :started_at
      t.datetime :completed_at
      t.integer :time_spent_seconds, default: 0
      
      # AI analysis results
      t.jsonb :ai_analysis, default: {}
      t.decimal :ai_score, precision: 5, scale: 2
      t.string :ai_classification
      t.text :ai_summary
      
      # Lead qualification (BANT/CHAMP)
      t.jsonb :qualification_data, default: {}
      t.string :lead_score
      t.boolean :qualified_lead, default: false
      
      # Response metadata
      t.jsonb :metadata, default: {}
      t.jsonb :utm_parameters, default: {}
      t.string :referrer_url
      t.string :landing_page
      
      # Geolocation (if enabled)
      t.string :country
      t.string :region
      t.string :city
      t.decimal :latitude, precision: 10, scale: 6
      t.decimal :longitude, precision: 10, scale: 6
      
      # Privacy and consent
      t.boolean :gdpr_consent, default: false
      t.jsonb :consent_data, default: {}
      
      # Integration flags
      t.boolean :exported, default: false
      t.datetime :exported_at
      t.jsonb :integration_status, default: {}

      t.timestamps null: false
    end

    # Indexes for performance (avoiding duplicate form_id and user_id indexes)
    add_index :form_responses, :session_id
    add_index :form_responses, :fingerprint
    add_index :form_responses, :status
    add_index :form_responses, :started_at
    add_index :form_responses, :completed_at
    add_index :form_responses, :qualified_lead
    add_index :form_responses, :exported
    add_index :form_responses, [:form_id, :status]
    add_index :form_responses, [:form_id, :completed_at]
    add_index :form_responses, [:user_id, :form_id]
  end
end
