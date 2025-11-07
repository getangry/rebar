class AddPerformanceIndexes < ActiveRecord::Migration[8.1]
  def change
    # Index for parent relationship lookups (used heavily in compute_inherited_permissions)
    # Query: WHERE tenant_id = ? AND relation = 'parent' AND actor = ? AND actor_id = ?
    add_index :rel_tuples, [:tenant_id, :relation, :actor, :actor_id],
              name: "idx_rt_parent_lookup",
              where: "relation = 'parent'"

    # Index for group membership lookups
    # Query: WHERE tenant_id = ? AND actor = ? AND actor_id = ? AND subject = 'group'
    add_index :rel_tuples, [:tenant_id, :actor, :actor_id, :subject],
              name: "idx_rt_actor_subject",
              where: "subject = 'group'"

    # Covering index for direct permission queries (most common path)
    # Includes all columns needed to avoid table lookups
    add_index :rel_tuples, [:tenant_id, :actor, :actor_id, :subject, :id, :relation],
              name: "idx_rt_actor_covering"
  end
end
