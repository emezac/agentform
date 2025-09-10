class AddAiOptimizationIndexes < ActiveRecord::Migration[8.0]
  def change
    # Partial index for AI-enabled forms with specific statuses
    add_index :forms, [:user_id, :ai_enabled, :status], 
              where: "ai_enabled = true AND status IN ('published', 'draft')",
              name: 'index_forms_ai_enabled_published'
    
    # Partial index for form responses with AI analysis
    add_index :form_responses, [:form_id, :completed_at], 
              where: "ai_analysis != '{}'::jsonb AND status = 'completed'",
              name: 'index_responses_with_ai_analysis'
    
    # Partial index for AI-enhanced questions by type
    add_index :form_questions, [:form_id, :question_type, :ai_enhanced], 
              where: "ai_enhanced = true",
              name: 'index_questions_ai_enhanced_by_type'
    
    # Composite index for AI credit queries
    add_index :users, [:ai_credits_used, :monthly_ai_limit, :active], 
              where: "active = true AND monthly_ai_limit > 0",
              name: 'index_users_ai_credits_active'
    
    # Index for AI workflow processing
    add_index :forms, [:ai_enabled, :updated_at], 
              where: "ai_enabled = true",
              name: 'index_forms_ai_workflow_processing'
    
    # Index for question responses with AI analysis
    add_index :question_responses, [:form_response_id, :ai_confidence], 
              where: "ai_confidence IS NOT NULL",
              name: 'index_question_responses_ai_confidence'
    
    # Index for dynamic questions by status and priority
    add_index :dynamic_questions, [:form_response_id, :status, :priority], 
              name: 'index_dynamic_questions_status_priority'
    
    # Index for form analytics with AI metrics
    add_index :form_analytics, [:form_id, :ai_analyses_count], 
              where: "ai_analyses_count > 0",
              name: 'index_form_analytics_ai_metrics'
    
    # Composite index for user AI usage patterns
    add_index :users, [:subscription_status, :ai_credits_used], 
              name: 'index_users_subscription_ai_usage'
    
    # Index for forms with AI configuration
    add_index :forms, [:category, :ai_enabled], 
              where: "ai_enabled = true",
              name: 'index_forms_category_ai_enabled'
  end
end
