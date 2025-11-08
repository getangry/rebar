class CreateRelTuples < ActiveRecord::Migration[8.1]
  def change
    # Enable UUID extension for all tables
    enable_extension 'pgcrypto'

    create_table :rel_tuples, id: :uuid do |t|
      # Multi-tenancy
      t.string :tenant_id, null: false, default: 'default', index: true

      # Subject (the resource being accessed)
      t.string :subject, null: false, index: true
      t.string :subject_id, null: false, index: true

      # Relation (the permission/role)
      t.string :relation, null: false, index: true

      # Actor (who has the permission)
      t.string :actor, null: false, index: true
      t.string :actor_id, null: false, index: true
      t.string :actor_rel # Optional: for usersets (e.g., group#member)

      # Metadata
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    # Composite indexes for common query patterns
    add_index :rel_tuples, [:tenant_id, :subject, :subject_id, :relation], name: 'idx_rt_subj_rel'
    add_index :rel_tuples, [:tenant_id, :actor, :actor_id], name: 'idx_rt_actor'
    add_index :rel_tuples, [:tenant_id, :subject, :relation, :actor], name: 'idx_rt_subj_rel_actor'

    # Performance indexes
    # Parent relationship lookups (used in compute_inherited_permissions)
    add_index :rel_tuples, [:tenant_id, :relation, :actor, :actor_id],
              name: 'idx_rt_parent_lookup',
              where: "relation = 'parent'"

    # Group membership lookups
    add_index :rel_tuples, [:tenant_id, :actor, :actor_id, :subject],
              name: 'idx_rt_actor_subject',
              where: "subject = 'group'"

    # Covering index for direct permission queries (most common path)
    add_index :rel_tuples, [:tenant_id, :actor, :actor_id, :subject, :subject_id, :relation],
              name: 'idx_rt_actor_covering'

    # Unique constraint to prevent duplicate tuples
    add_index :rel_tuples,
              "tenant_id, subject, subject_id, relation, actor, actor_id, COALESCE(actor_rel,'')",
              unique: true,
              name: 'uq_rt_fact'
  end
end
