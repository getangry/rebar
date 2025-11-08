class CreateAuditLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_logs, id: :uuid do |t|
      # Who
      t.string :tenant_id, null: false, default: 'default'
      t.string :service_id, null: false
      t.string :actor_user_id              # Optional: if we track the actual user
      t.string :ip_address
      t.string :user_agent

      # What
      t.string :action, null: false        # create, delete, update
      t.string :resource_type, null: false # rel_tuple, service_grant, etc.

      # Tuple data (what changed)
      t.string :subject
      t.string :object_id
      t.string :relation
      t.string :actor
      t.string :actor_id
      t.string :actor_rel

      # For updates - store before/after state
      t.jsonb :before_state
      t.jsonb :after_state

      # Why & additional context
      t.string :reason
      t.jsonb :metadata, default: {}       # Any additional context

      # When
      t.datetime :created_at, null: false, default: -> { 'NOW()' }
    end

    # Indexes for common queries
    add_index :audit_logs, [:tenant_id, :created_at], name: 'idx_audit_tenant_time'
    add_index :audit_logs, [:tenant_id, :service_id], name: 'idx_audit_tenant_service'
    add_index :audit_logs, [:tenant_id, :subject, :object_id], name: 'idx_audit_resource'
    add_index :audit_logs, [:tenant_id, :action], name: 'idx_audit_action'
    add_index :audit_logs, [:tenant_id, :actor, :actor_id], name: 'idx_audit_actor'
  end
end
