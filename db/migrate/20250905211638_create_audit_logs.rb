class CreateAuditLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :audit_logs, id: :uuid do |t|
      t.string :event_type, null: false
      t.references :user, null: true, foreign_key: true, type: :uuid
      t.string :ip_address
      t.json :details, default: {}
      t.datetime :created_at, null: false
    end

    add_index :audit_logs, :event_type
    add_index :audit_logs, :created_at
    add_index :audit_logs, [:user_id, :created_at]
    add_index :audit_logs, [:event_type, :created_at]
  end
end
