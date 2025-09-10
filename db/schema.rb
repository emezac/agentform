# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_09_09_021513) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "admin_notifications", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "event_type", null: false
    t.string "title", null: false
    t.text "message"
    t.uuid "user_id"
    t.json "metadata", default: {}
    t.datetime "read_at"
    t.string "priority", default: "normal"
    t.string "category"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_admin_notifications_on_created_at"
    t.index ["event_type", "created_at"], name: "index_admin_notifications_on_event_type_and_created_at"
    t.index ["event_type"], name: "index_admin_notifications_on_event_type"
    t.index ["priority"], name: "index_admin_notifications_on_priority"
    t.index ["read_at"], name: "index_admin_notifications_on_read_at"
    t.index ["user_id"], name: "index_admin_notifications_on_user_id"
  end

  create_table "analysis_reports", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "form_response_id", null: false
    t.string "report_type", null: false
    t.text "markdown_content", null: false
    t.json "metadata"
    t.string "status", default: "generating"
    t.string "file_path"
    t.integer "file_size"
    t.decimal "ai_cost", precision: 10, scale: 4
    t.datetime "generated_at"
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["form_response_id"], name: "index_analysis_reports_on_form_response_id"
    t.index ["generated_at"], name: "index_analysis_reports_on_generated_at"
    t.index ["report_type"], name: "index_analysis_reports_on_report_type"
    t.index ["status"], name: "index_analysis_reports_on_status"
  end

  create_table "api_tokens", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "name", null: false
    t.string "token", null: false
    t.jsonb "permissions", default: {}
    t.boolean "active", default: true
    t.datetime "last_used_at"
    t.datetime "expires_at"
    t.integer "usage_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_api_tokens_on_active"
    t.index ["expires_at"], name: "index_api_tokens_on_expires_at"
    t.index ["last_used_at"], name: "index_api_tokens_on_last_used_at"
    t.index ["token"], name: "index_api_tokens_on_token", unique: true
    t.index ["user_id", "active"], name: "index_api_tokens_on_user_id_and_active"
    t.index ["user_id"], name: "index_api_tokens_on_user_id"
  end

  create_table "audit_logs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "event_type", null: false
    t.uuid "user_id"
    t.string "ip_address"
    t.json "details", default: {}
    t.datetime "created_at", null: false
    t.index ["created_at"], name: "index_audit_logs_on_created_at"
    t.index ["event_type", "created_at"], name: "index_audit_logs_on_event_type_and_created_at"
    t.index ["event_type", "user_id", "created_at"], name: "idx_audit_logs_admin_monitoring"
    t.index ["event_type"], name: "index_audit_logs_on_event_type"
    t.index ["user_id", "created_at"], name: "index_audit_logs_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
  end

  create_table "discount_code_usages", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "discount_code_id", null: false
    t.uuid "user_id", null: false
    t.string "subscription_id"
    t.integer "original_amount", null: false
    t.integer "discount_amount", null: false
    t.integer "final_amount", null: false
    t.datetime "used_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["discount_code_id", "used_at"], name: "idx_discount_usages_code_timeline"
    t.index ["discount_code_id"], name: "idx_discount_usages_code"
    t.index ["used_at", "discount_amount"], name: "idx_discount_usages_analytics"
    t.index ["user_id"], name: "idx_discount_usages_user"
    t.index ["user_id"], name: "idx_one_discount_per_user", unique: true
    t.check_constraint "discount_amount <= original_amount", name: "discount_not_greater_than_original"
    t.check_constraint "discount_amount > 0", name: "discount_amount_positive"
    t.check_constraint "final_amount = (original_amount - discount_amount)", name: "final_amount_calculation_correct"
    t.check_constraint "final_amount >= 0", name: "final_amount_non_negative"
    t.check_constraint "original_amount > 0", name: "original_amount_positive"
  end

  create_table "discount_codes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "code", limit: 50, null: false
    t.integer "discount_percentage", null: false
    t.integer "max_usage_count"
    t.integer "current_usage_count", default: 0, null: false
    t.datetime "expires_at", precision: nil
    t.boolean "active", default: true, null: false
    t.uuid "created_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((code)::text)", name: "idx_discount_codes_code_unique", unique: true
    t.index ["active", "created_at"], name: "idx_discount_codes_active_created_at"
    t.index ["active", "expires_at", "current_usage_count"], name: "idx_discount_codes_analytics"
    t.index ["active"], name: "idx_discount_codes_active"
    t.index ["current_usage_count", "max_usage_count"], name: "idx_discount_codes_usage_tracking"
    t.index ["expires_at"], name: "idx_discount_codes_active_expiring", where: "((active = true) AND (expires_at IS NOT NULL))"
    t.index ["expires_at"], name: "idx_discount_codes_expires_at"
    t.check_constraint "current_usage_count >= 0", name: "current_usage_count_non_negative"
    t.check_constraint "discount_percentage >= 1 AND discount_percentage <= 99", name: "discount_percentage_range"
    t.check_constraint "max_usage_count IS NULL OR current_usage_count <= max_usage_count", name: "current_usage_within_max"
    t.check_constraint "max_usage_count IS NULL OR max_usage_count > 0", name: "max_usage_count_positive"
  end

  create_table "dynamic_questions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "form_response_id", null: false
    t.uuid "generated_from_question_id"
    t.string "question_type", null: false
    t.text "title", null: false
    t.text "description"
    t.jsonb "configuration", default: {}
    t.jsonb "generation_context", default: {}
    t.text "generation_prompt"
    t.string "generation_model"
    t.jsonb "answer_data", default: {}
    t.decimal "response_time_ms", precision: 8, scale: 2
    t.decimal "ai_confidence", precision: 5, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "answered_at"
    t.string "status", default: "pending", null: false
    t.integer "priority", default: 0
    t.decimal "response_quality_score", precision: 5, scale: 2
    t.index ["answered_at"], name: "index_dynamic_questions_on_answered_at"
    t.index ["created_at"], name: "index_dynamic_questions_on_created_at"
    t.index ["form_response_id", "answered_at"], name: "index_dynamic_questions_on_form_response_id_and_answered_at"
    t.index ["form_response_id", "question_type"], name: "index_dynamic_questions_on_form_response_id_and_question_type"
    t.index ["form_response_id", "status", "priority"], name: "index_dynamic_questions_status_priority"
    t.index ["form_response_id", "status"], name: "index_dynamic_questions_on_form_response_id_and_status"
    t.index ["form_response_id"], name: "index_dynamic_questions_on_form_response_id"
    t.index ["generated_from_question_id"], name: "index_dynamic_questions_on_generated_from_question_id"
    t.index ["question_type"], name: "index_dynamic_questions_on_question_type"
    t.index ["status"], name: "index_dynamic_questions_on_status"
  end

  create_table "export_jobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "form_id", null: false
    t.string "job_id", null: false
    t.string "export_type", null: false
    t.string "status", default: "pending"
    t.json "configuration", default: {}
    t.string "spreadsheet_id"
    t.string "spreadsheet_url"
    t.integer "records_exported", default: 0
    t.json "error_details"
    t.datetime "started_at"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["form_id"], name: "index_export_jobs_on_form_id"
    t.index ["job_id"], name: "index_export_jobs_on_job_id", unique: true
    t.index ["user_id", "status"], name: "index_export_jobs_on_user_id_and_status"
    t.index ["user_id"], name: "index_export_jobs_on_user_id"
  end

  create_table "form_analytics", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "form_id", null: false
    t.date "date"
    t.string "period_type", default: "daily", null: false
    t.integer "views_count", default: 0
    t.integer "unique_views_count", default: 0
    t.integer "started_responses_count", default: 0
    t.integer "completed_responses_count", default: 0
    t.integer "abandoned_responses_count", default: 0
    t.decimal "conversion_rate", precision: 5, scale: 2, default: "0.0"
    t.decimal "completion_rate", precision: 5, scale: 2, default: "0.0"
    t.decimal "abandonment_rate", precision: 5, scale: 2, default: "0.0"
    t.integer "avg_completion_time", default: 0
    t.integer "median_completion_time", default: 0
    t.integer "avg_time_per_question", default: 0
    t.decimal "avg_response_quality", precision: 5, scale: 2, default: "0.0"
    t.integer "validation_errors_count", default: 0
    t.integer "skip_count", default: 0
    t.integer "ai_analyses_count", default: 0
    t.decimal "avg_ai_confidence", precision: 5, scale: 2, default: "0.0"
    t.integer "qualified_leads_count", default: 0
    t.decimal "lead_qualification_rate", precision: 5, scale: 2, default: "0.0"
    t.jsonb "traffic_sources", default: {}
    t.jsonb "utm_data", default: {}
    t.jsonb "referrer_data", default: {}
    t.jsonb "device_breakdown", default: {}
    t.jsonb "browser_breakdown", default: {}
    t.jsonb "os_breakdown", default: {}
    t.jsonb "country_breakdown", default: {}
    t.jsonb "region_breakdown", default: {}
    t.jsonb "question_analytics", default: {}
    t.jsonb "drop_off_points", default: {}
    t.integer "avg_load_time_ms", default: 0
    t.integer "error_count", default: 0
    t.jsonb "error_breakdown", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["completion_rate"], name: "index_form_analytics_on_completion_rate"
    t.index ["conversion_rate"], name: "index_form_analytics_on_conversion_rate"
    t.index ["date"], name: "index_form_analytics_on_date"
    t.index ["form_id", "ai_analyses_count"], name: "index_form_analytics_ai_metrics", where: "(ai_analyses_count > 0)"
    t.index ["form_id", "date"], name: "index_form_analytics_on_form_id_and_date", unique: true
    t.index ["form_id", "period_type"], name: "index_form_analytics_on_form_id_and_period_type"
    t.index ["form_id"], name: "index_form_analytics_on_form_id"
    t.index ["period_type"], name: "index_form_analytics_on_period_type"
  end

  create_table "form_questions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "form_id", null: false
    t.string "title", null: false
    t.text "description"
    t.string "question_type", null: false
    t.integer "position", null: false
    t.jsonb "question_config", default: {}
    t.jsonb "validation_rules", default: {}
    t.jsonb "display_options", default: {}
    t.jsonb "conditional_logic", default: {}
    t.boolean "conditional_enabled", default: false
    t.boolean "ai_enhanced", default: false
    t.jsonb "ai_config", default: {}
    t.text "ai_prompt"
    t.boolean "required", default: false
    t.boolean "hidden", default: false
    t.boolean "read_only", default: false
    t.integer "responses_count", default: 0
    t.integer "skip_count", default: 0
    t.decimal "completion_rate", precision: 5, scale: 2, default: "0.0"
    t.string "reference_id"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ai_config"], name: "index_form_questions_on_ai_config", using: :gin
    t.index ["ai_enhanced", "question_type"], name: "index_form_questions_on_ai_enhanced_and_type"
    t.index ["ai_enhanced"], name: "index_form_questions_on_ai_enhanced"
    t.index ["conditional_enabled"], name: "index_form_questions_on_conditional_enabled"
    t.index ["form_id", "ai_enhanced"], name: "index_form_questions_on_form_id_and_ai_enhanced"
    t.index ["form_id", "hidden"], name: "index_form_questions_on_form_id_and_hidden"
    t.index ["form_id", "position"], name: "index_form_questions_on_form_id_and_position"
    t.index ["form_id", "question_type", "ai_enhanced"], name: "index_questions_ai_enhanced_by_type", where: "(ai_enhanced = true)"
    t.index ["form_id"], name: "index_form_questions_on_form_id"
    t.index ["metadata"], name: "index_form_questions_on_metadata", using: :gin
    t.index ["question_type"], name: "index_form_questions_on_question_type"
    t.index ["reference_id"], name: "index_form_questions_on_reference_id"
    t.index ["required"], name: "index_form_questions_on_required"
  end

  create_table "form_responses", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "form_id", null: false
    t.uuid "user_id"
    t.string "session_id"
    t.string "fingerprint"
    t.inet "ip_address"
    t.string "user_agent"
    t.string "status", default: "in_progress", null: false
    t.integer "current_question_position", default: 1
    t.decimal "progress_percentage", precision: 5, scale: 2, default: "0.0"
    t.datetime "started_at"
    t.datetime "completed_at"
    t.integer "time_spent_seconds", default: 0
    t.jsonb "ai_analysis", default: {}
    t.decimal "ai_score", precision: 5, scale: 2
    t.string "ai_classification"
    t.text "ai_summary"
    t.jsonb "qualification_data", default: {}
    t.string "lead_score"
    t.boolean "qualified_lead", default: false
    t.jsonb "metadata", default: {}
    t.jsonb "utm_parameters", default: {}
    t.string "referrer_url"
    t.string "landing_page"
    t.string "country"
    t.string "region"
    t.string "city"
    t.decimal "latitude", precision: 10, scale: 6
    t.decimal "longitude", precision: 10, scale: 6
    t.boolean "gdpr_consent", default: false
    t.jsonb "consent_data", default: {}
    t.boolean "exported", default: false
    t.datetime "exported_at"
    t.jsonb "integration_status", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "last_activity_at"
    t.datetime "abandoned_at"
    t.string "abandonment_reason"
    t.datetime "paused_at"
    t.datetime "resumed_at"
    t.jsonb "completion_data"
    t.jsonb "draft_data"
    t.decimal "quality_score"
    t.decimal "sentiment_score"
    t.index ["completed_at"], name: "index_form_responses_on_completed_at"
    t.index ["exported"], name: "index_form_responses_on_exported"
    t.index ["fingerprint"], name: "index_form_responses_on_fingerprint"
    t.index ["form_id", "completed_at"], name: "index_form_responses_on_form_id_and_completed_at"
    t.index ["form_id", "completed_at"], name: "index_responses_with_ai_analysis", where: "((ai_analysis <> '{}'::jsonb) AND ((status)::text = 'completed'::text))"
    t.index ["form_id", "status"], name: "index_form_responses_on_form_id_and_status"
    t.index ["form_id"], name: "index_form_responses_on_form_id"
    t.index ["qualified_lead"], name: "index_form_responses_on_qualified_lead"
    t.index ["session_id"], name: "index_form_responses_on_session_id"
    t.index ["started_at"], name: "index_form_responses_on_started_at"
    t.index ["status"], name: "index_form_responses_on_status"
    t.index ["user_id", "form_id"], name: "index_form_responses_on_user_id_and_form_id"
    t.index ["user_id"], name: "index_form_responses_on_user_id"
  end

  create_table "form_templates", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "category", null: false
    t.string "visibility", default: "public"
    t.uuid "creator_id"
    t.jsonb "template_data", null: false
    t.jsonb "preview_data", default: {}
    t.integer "usage_count", default: 0
    t.decimal "rating", precision: 3, scale: 2
    t.integer "reviews_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "estimated_time_minutes"
    t.text "features"
    t.boolean "payment_enabled", default: false, null: false
    t.jsonb "required_features", default: []
    t.string "setup_complexity", default: "simple"
    t.jsonb "metadata", default: {}
    t.index ["category", "visibility"], name: "index_form_templates_on_category_and_visibility"
    t.index ["category"], name: "index_form_templates_on_category"
    t.index ["creator_id"], name: "index_form_templates_on_creator_id"
    t.index ["metadata"], name: "index_form_templates_on_metadata", using: :gin
    t.index ["payment_enabled"], name: "index_form_templates_on_payment_enabled"
    t.index ["rating"], name: "index_form_templates_on_rating"
    t.index ["setup_complexity"], name: "index_form_templates_on_setup_complexity"
    t.index ["usage_count"], name: "index_form_templates_on_usage_count"
    t.index ["visibility"], name: "index_form_templates_on_visibility"
  end

  create_table "forms", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "status", default: "draft", null: false
    t.string "category", default: "general"
    t.string "share_token", null: false
    t.boolean "public", default: false
    t.uuid "user_id", null: false
    t.jsonb "form_settings", default: {}
    t.jsonb "ai_configuration", default: {}
    t.jsonb "style_configuration", default: {}
    t.jsonb "integration_settings", default: {}
    t.jsonb "notification_settings", default: {}
    t.integer "views_count", default: 0
    t.integer "responses_count", default: 0
    t.integer "completion_count", default: 0
    t.decimal "completion_rate", precision: 5, scale: 2, default: "0.0"
    t.datetime "published_at"
    t.datetime "expires_at"
    t.boolean "accepts_responses", default: true
    t.boolean "ai_enabled", default: false
    t.string "workflow_class"
    t.jsonb "workflow_config", default: {}
    t.boolean "show_branding", default: true
    t.string "custom_domain"
    t.string "redirect_url"
    t.boolean "requires_login", default: false
    t.string "password_hash"
    t.jsonb "access_restrictions", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "template_id"
    t.jsonb "metadata", default: {}
    t.boolean "payment_setup_complete", default: false, null: false
    t.index ["ai_configuration"], name: "index_forms_on_ai_configuration", using: :gin
    t.index ["ai_enabled", "status"], name: "index_forms_on_ai_enabled_and_status"
    t.index ["ai_enabled", "updated_at"], name: "index_forms_ai_workflow_processing", where: "(ai_enabled = true)"
    t.index ["ai_enabled"], name: "index_forms_on_ai_enabled"
    t.index ["category", "ai_enabled"], name: "index_forms_category_ai_enabled", where: "(ai_enabled = true)"
    t.index ["category"], name: "index_forms_on_category"
    t.index ["custom_domain"], name: "index_forms_on_custom_domain", unique: true
    t.index ["expires_at"], name: "index_forms_on_expires_at"
    t.index ["metadata"], name: "index_forms_on_metadata", using: :gin
    t.index ["payment_setup_complete"], name: "index_forms_on_payment_setup_complete"
    t.index ["public", "status"], name: "index_forms_on_public_and_status"
    t.index ["public"], name: "index_forms_on_public"
    t.index ["published_at"], name: "index_forms_on_published_at"
    t.index ["share_token"], name: "index_forms_on_share_token", unique: true
    t.index ["status"], name: "index_forms_on_status"
    t.index ["user_id", "ai_enabled", "status"], name: "index_forms_ai_enabled_published", where: "((ai_enabled = true) AND ((status)::text = ANY (ARRAY[('published'::character varying)::text, ('draft'::character varying)::text])))"
    t.index ["user_id", "ai_enabled"], name: "index_forms_on_user_id_and_ai_enabled"
    t.index ["user_id", "payment_setup_complete"], name: "index_forms_on_user_id_and_payment_setup_complete"
    t.index ["user_id", "status"], name: "index_forms_on_user_id_and_status"
    t.index ["user_id"], name: "index_forms_on_user_id"
  end

  create_table "google_integrations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "access_token", null: false
    t.string "refresh_token", null: false
    t.datetime "token_expires_at", null: false
    t.string "scope", null: false
    t.json "user_info"
    t.boolean "active", default: true
    t.datetime "last_used_at"
    t.integer "usage_count", default: 0
    t.json "error_log", default: []
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token_expires_at"], name: "index_google_integrations_on_token_expires_at"
    t.index ["user_id", "active"], name: "index_google_integrations_on_user_id_and_active"
    t.index ["user_id"], name: "index_google_integrations_on_user_id"
  end

  create_table "google_sheets_integrations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "form_id", null: false
    t.string "spreadsheet_id", null: false
    t.string "sheet_name", default: "Responses"
    t.boolean "auto_sync", default: false
    t.datetime "last_sync_at"
    t.json "field_mapping", default: {}
    t.boolean "active", default: true
    t.text "error_message"
    t.integer "sync_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["form_id"], name: "index_google_sheets_integrations_on_form_id"
    t.index ["spreadsheet_id"], name: "index_google_sheets_integrations_on_spreadsheet_id"
  end

  create_table "payment_analytics", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "event_type", null: false
    t.uuid "user_id", null: false
    t.string "user_subscription_tier"
    t.datetime "timestamp", null: false
    t.jsonb "context", default: {}, null: false
    t.string "session_id"
    t.string "user_agent"
    t.string "ip_address"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["context"], name: "index_payment_analytics_on_context", using: :gin
    t.index ["event_type", "timestamp"], name: "index_payment_analytics_on_event_type_and_timestamp"
    t.index ["session_id"], name: "index_payment_analytics_on_session_id"
    t.index ["user_id", "timestamp"], name: "index_payment_analytics_on_user_id_and_timestamp"
    t.index ["user_id"], name: "index_payment_analytics_on_user_id"
    t.index ["user_subscription_tier"], name: "index_payment_analytics_on_user_subscription_tier"
  end

  create_table "payment_transactions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "form_id", null: false
    t.uuid "form_response_id", null: false
    t.string "stripe_payment_intent_id", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.string "currency", limit: 3, default: "USD", null: false
    t.string "status", default: "pending", null: false
    t.string "payment_method", null: false
    t.json "metadata", default: {}
    t.text "failure_reason"
    t.datetime "processed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["form_id", "status"], name: "index_payment_transactions_on_form_id_and_status"
    t.index ["form_id"], name: "index_payment_transactions_on_form_id"
    t.index ["form_response_id"], name: "index_payment_transactions_on_form_response_id"
    t.index ["processed_at"], name: "index_payment_transactions_on_processed_at"
    t.index ["status", "processed_at"], name: "idx_payment_transactions_status_processed"
    t.index ["status"], name: "index_payment_transactions_on_status"
    t.index ["stripe_payment_intent_id"], name: "index_payment_transactions_on_stripe_payment_intent_id", unique: true
    t.index ["user_id", "created_at"], name: "index_payment_transactions_on_user_id_and_created_at"
    t.index ["user_id", "status", "processed_at"], name: "idx_payment_transactions_user_analytics"
    t.index ["user_id"], name: "index_payment_transactions_on_user_id"
    t.check_constraint "amount > 0::numeric", name: "payment_amount_positive"
    t.check_constraint "currency::text = ANY (ARRAY['USD'::character varying::text, 'EUR'::character varying::text, 'GBP'::character varying::text, 'CAD'::character varying::text, 'AUD'::character varying::text])", name: "valid_currency"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying::text, 'processing'::character varying::text, 'succeeded'::character varying::text, 'failed'::character varying::text, 'canceled'::character varying::text])", name: "valid_payment_status"
  end

  create_table "question_responses", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "form_response_id", null: false
    t.uuid "form_question_id", null: false
    t.text "answer_text"
    t.jsonb "answer_data", default: {}
    t.jsonb "processed_answer", default: {}
    t.integer "time_spent_seconds", default: 0
    t.integer "revision_count", default: 0
    t.boolean "skipped", default: false
    t.string "skip_reason"
    t.jsonb "ai_analysis", default: {}
    t.decimal "ai_confidence", precision: 5, scale: 2
    t.text "ai_insights"
    t.boolean "answer_valid", default: true
    t.jsonb "validation_errors", default: {}
    t.decimal "quality_score", precision: 5, scale: 2
    t.integer "focus_time_seconds", default: 0
    t.integer "blur_count", default: 0
    t.integer "keystroke_count", default: 0
    t.jsonb "interaction_data", default: {}
    t.boolean "triggered_followup", default: false
    t.jsonb "followup_config", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "ai_analysis_results"
    t.datetime "ai_analysis_requested_at"
    t.integer "response_time_ms"
    t.index ["answer_valid"], name: "index_question_responses_on_answer_valid"
    t.index ["created_at"], name: "index_question_responses_on_created_at"
    t.index ["form_question_id"], name: "index_question_responses_on_form_question_id"
    t.index ["form_response_id", "ai_confidence"], name: "index_question_responses_ai_confidence", where: "(ai_confidence IS NOT NULL)"
    t.index ["form_response_id", "form_question_id"], name: "idx_question_responses_unique", unique: true
    t.index ["form_response_id"], name: "index_question_responses_on_form_response_id"
    t.index ["skipped"], name: "index_question_responses_on_skipped"
    t.index ["triggered_followup"], name: "index_question_responses_on_triggered_followup"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.string "first_name"
    t.string "last_name"
    t.string "role", default: "user", null: false
    t.jsonb "preferences", default: {}
    t.jsonb "ai_settings", default: {}
    t.decimal "ai_credits_used", precision: 10, scale: 4, default: "0.0"
    t.decimal "monthly_ai_limit", precision: 10, scale: 4, default: "10.0"
    t.string "subscription_status", default: "free"
    t.datetime "subscription_expires_at"
    t.string "stripe_customer_id"
    t.boolean "active", default: true
    t.datetime "last_activity_at"
    t.boolean "onboarding_completed", default: false
    t.jsonb "onboarding_progress", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "subscription_tier", default: "basic", null: false
    t.datetime "trial_expires_at"
    t.text "stripe_publishable_key"
    t.text "stripe_secret_key"
    t.text "stripe_webhook_secret"
    t.string "stripe_account_id"
    t.boolean "stripe_enabled", default: false, null: false
    t.boolean "discount_code_used", default: false, null: false
    t.datetime "suspended_at", precision: nil
    t.text "suspended_reason"
    t.datetime "trial_ends_at"
    t.index ["active"], name: "index_users_on_active"
    t.index ["ai_credits_used", "monthly_ai_limit", "active"], name: "index_users_ai_credits_active", where: "((active = true) AND (monthly_ai_limit > (0)::numeric))"
    t.index ["ai_credits_used", "monthly_ai_limit"], name: "index_users_on_ai_credits"
    t.index ["ai_credits_used"], name: "index_users_on_ai_credits_used"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["created_at"], name: "idx_users_active_created_at", where: "(suspended_at IS NULL)"
    t.index ["discount_code_used"], name: "index_users_on_discount_code_used"
    t.index ["email", "first_name", "last_name"], name: "idx_users_search_fields"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["last_activity_at"], name: "index_users_on_last_activity_at"
    t.index ["monthly_ai_limit"], name: "index_users_on_monthly_ai_limit"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role", "created_at"], name: "idx_users_role_created_at"
    t.index ["role", "subscription_tier", "suspended_at", "created_at"], name: "idx_users_admin_filters"
    t.index ["role"], name: "index_users_on_role"
    t.index ["stripe_account_id"], name: "index_users_on_stripe_account_id"
    t.index ["stripe_customer_id"], name: "index_users_on_stripe_customer_id", unique: true
    t.index ["stripe_enabled"], name: "index_users_on_stripe_enabled"
    t.index ["subscription_status", "ai_credits_used"], name: "index_users_subscription_ai_usage"
    t.index ["subscription_status"], name: "index_users_on_subscription_status"
    t.index ["subscription_tier", "created_at"], name: "idx_users_tier_created_at"
    t.index ["subscription_tier", "suspended_at", "created_at"], name: "idx_users_dashboard_stats"
    t.index ["suspended_at", "created_at"], name: "idx_users_suspended_created_at"
    t.index ["suspended_at"], name: "index_users_on_suspended_at"
    t.index ["trial_ends_at"], name: "index_users_on_trial_ends_at"
    t.check_constraint "ai_credits_used >= 0::numeric", name: "ai_credits_used_non_negative"
    t.check_constraint "monthly_ai_limit > 0::numeric", name: "monthly_ai_limit_positive"
    t.check_constraint "role::text = ANY (ARRAY['user'::character varying::text, 'admin'::character varying::text, 'superadmin'::character varying::text])", name: "valid_user_role"
    t.check_constraint "subscription_tier::text = ANY (ARRAY['basic'::character varying, 'premium'::character varying]::text[])", name: "valid_subscription_tier"
  end

  add_foreign_key "admin_notifications", "users"
  add_foreign_key "analysis_reports", "form_responses"
  add_foreign_key "api_tokens", "users"
  add_foreign_key "audit_logs", "users"
  add_foreign_key "discount_code_usages", "discount_codes"
  add_foreign_key "discount_code_usages", "users"
  add_foreign_key "discount_codes", "users", column: "created_by_id"
  add_foreign_key "dynamic_questions", "form_questions", column: "generated_from_question_id"
  add_foreign_key "dynamic_questions", "form_responses"
  add_foreign_key "export_jobs", "forms"
  add_foreign_key "export_jobs", "users"
  add_foreign_key "form_analytics", "forms"
  add_foreign_key "form_questions", "forms"
  add_foreign_key "form_responses", "forms"
  add_foreign_key "form_responses", "users"
  add_foreign_key "form_templates", "users", column: "creator_id"
  add_foreign_key "forms", "users"
  add_foreign_key "google_integrations", "users"
  add_foreign_key "google_sheets_integrations", "forms"
  add_foreign_key "payment_analytics", "users"
  add_foreign_key "payment_transactions", "form_responses"
  add_foreign_key "payment_transactions", "forms"
  add_foreign_key "payment_transactions", "users"
  add_foreign_key "question_responses", "form_questions"
  add_foreign_key "question_responses", "form_responses"
end
