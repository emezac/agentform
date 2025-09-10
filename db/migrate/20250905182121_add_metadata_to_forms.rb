class AddMetadataToForms < ActiveRecord::Migration[8.0]
  def change
    add_column :forms, :metadata, :jsonb, default: {}
    
    # Add GIN index for efficient JSON queries on metadata
    add_index :forms, :metadata, using: :gin
  end
end
