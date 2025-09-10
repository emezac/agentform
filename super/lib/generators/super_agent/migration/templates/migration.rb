# frozen_string_literal: true

class CreateSuperAgentExecutions < ActiveRecord::Migration[7.1]
  def change
    create_table :super_agent_executions do |t|
      t.string :workflow_class_name, null: false
      t.string :status, null: false, default: 'pending'
      t.jsonb :initial_context, null: false, default: {}
      t.jsonb :final_output, default: {}
      t.text :error
      t.string :failed_task_name
      t.jsonb :full_trace, default: []
      t.datetime :started_at
      t.datetime :completed_at
      t.string :job_id
      t.string :workflow_execution_id
      
      # Optional: add user association if needed
      # t.references :user, foreign_key: true
      
      t.timestamps
    end

    add_index :super_agent_executions, :workflow_execution_id, unique: true
    add_index :super_agent_executions, :job_id
    add_index :super_agent_executions, :status
    add_index :super_agent_executions, :created_at
  end
end