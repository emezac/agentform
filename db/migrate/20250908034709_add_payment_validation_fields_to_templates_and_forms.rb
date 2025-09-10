class AddPaymentValidationFieldsToTemplatesAndForms < ActiveRecord::Migration[8.0]
  def change
    # Add payment validation fields to form_templates
    add_column :form_templates, :payment_enabled, :boolean, default: false, null: false
    add_column :form_templates, :required_features, :jsonb, default: []
    add_column :form_templates, :setup_complexity, :string, default: 'simple'
    
    # Add payment setup status to forms
    add_column :forms, :payment_setup_complete, :boolean, default: false, null: false
    
    # Add indexes for performance
    add_index :form_templates, :payment_enabled
    add_index :form_templates, :setup_complexity
    add_index :forms, :payment_setup_complete
    add_index :forms, [:user_id, :payment_setup_complete]
  end
end
