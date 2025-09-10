class CreateFormAnalytics < ActiveRecord::Migration[8.0]
  def change
    create_table :form_analytics, id: :uuid do |t|
      # Form association
      t.references :form, null: false, foreign_key: true, type: :uuid
      
      # Time period for analytics (daily, weekly, monthly aggregations)
      t.date :date
      t.string :period_type, null: false, default: 'daily' # daily, weekly, monthly
      
      # Basic metrics
      t.integer :views_count, default: 0
      t.integer :unique_views_count, default: 0
      t.integer :started_responses_count, default: 0
      t.integer :completed_responses_count, default: 0
      t.integer :abandoned_responses_count, default: 0
      
      # Conversion metrics
      t.decimal :conversion_rate, precision: 5, scale: 2, default: 0.0
      t.decimal :completion_rate, precision: 5, scale: 2, default: 0.0
      t.decimal :abandonment_rate, precision: 5, scale: 2, default: 0.0
      
      # Time metrics (in seconds)
      t.integer :avg_completion_time, default: 0
      t.integer :median_completion_time, default: 0
      t.integer :avg_time_per_question, default: 0
      
      # Quality metrics
      t.decimal :avg_response_quality, precision: 5, scale: 2, default: 0.0
      t.integer :validation_errors_count, default: 0
      t.integer :skip_count, default: 0
      
      # AI metrics
      t.integer :ai_analyses_count, default: 0
      t.decimal :avg_ai_confidence, precision: 5, scale: 2, default: 0.0
      t.integer :qualified_leads_count, default: 0
      t.decimal :lead_qualification_rate, precision: 5, scale: 2, default: 0.0
      
      # Traffic sources
      t.jsonb :traffic_sources, default: {}
      t.jsonb :utm_data, default: {}
      t.jsonb :referrer_data, default: {}
      
      # Device and browser analytics
      t.jsonb :device_breakdown, default: {}
      t.jsonb :browser_breakdown, default: {}
      t.jsonb :os_breakdown, default: {}
      
      # Geographic data
      t.jsonb :country_breakdown, default: {}
      t.jsonb :region_breakdown, default: {}
      
      # Question-level analytics
      t.jsonb :question_analytics, default: {}
      t.jsonb :drop_off_points, default: {}
      
      # Performance metrics
      t.integer :avg_load_time_ms, default: 0
      t.integer :error_count, default: 0
      t.jsonb :error_breakdown, default: {}

      t.timestamps null: false
    end

    # Indexes for performance
    add_index :form_analytics, [:form_id, :date], unique: true
    add_index :form_analytics, [:form_id, :period_type]
    add_index :form_analytics, :date
    add_index :form_analytics, :period_type
    add_index :form_analytics, :conversion_rate
    add_index :form_analytics, :completion_rate
  end
end
