class AddAiIndexesToFormsAndQuestions < ActiveRecord::Migration[8.0]
  def change
    # Add performance indexes for AI-related queries on forms
    add_index :forms, [:ai_enabled, :status], name: 'index_forms_on_ai_enabled_and_status'
    add_index :forms, [:user_id, :ai_enabled], name: 'index_forms_on_user_id_and_ai_enabled'
    
    # Add performance indexes for AI-related queries on form_questions
    add_index :form_questions, [:form_id, :ai_enhanced], name: 'index_form_questions_on_form_id_and_ai_enhanced'
    add_index :form_questions, [:ai_enhanced, :question_type], name: 'index_form_questions_on_ai_enhanced_and_type'
    
    # Add indexes for metadata queries (JSON columns)
    add_index :forms, :ai_configuration, using: :gin
    add_index :form_questions, :ai_config, using: :gin
    add_index :form_questions, :metadata, using: :gin
  end
end
