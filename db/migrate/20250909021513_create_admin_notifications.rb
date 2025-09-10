class CreateAdminNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :admin_notifications, id: :uuid do |t|
      t.string :event_type, null: false
      t.string :title, null: false
      t.text :message
      t.references :user, null: true, foreign_key: true, type: :uuid
      t.json :metadata, default: {}
      t.datetime :read_at
      t.string :priority, default: 'normal'
      t.string :category

      t.timestamps
    end

    add_index :admin_notifications, :event_type
    add_index :admin_notifications, :priority
    add_index :admin_notifications, :read_at
    add_index :admin_notifications, :created_at
    add_index :admin_notifications, [:event_type, :created_at]
  end
end
