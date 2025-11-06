class RenameTupleColumns < ActiveRecord::Migration[7.1]
  def change
    # Rename columns in rel_tuples table
    rename_column :rel_tuples, :ns, :subject
    rename_column :rel_tuples, :subj_ns, :actor
    rename_column :rel_tuples, :subj_id, :actor_id
    rename_column :rel_tuples, :subj_rel, :actor_rel

    # Drop old indexes
    remove_index :rel_tuples, name: "idx_rt_obj_rel"
    remove_index :rel_tuples, name: "idx_rt_subj"
    remove_index :rel_tuples, name: "idx_rt_obj_rel_subjns"
    remove_index :rel_tuples, name: "uq_rt_fact"

    # Add new indexes with new column names
    add_index :rel_tuples, [:tenant_id, :subject, :id, :relation], name: "idx_rt_subj_rel"
    add_index :rel_tuples, [:tenant_id, :actor, :actor_id], name: "idx_rt_actor"
    add_index :rel_tuples, [:tenant_id, :subject, :relation, :actor], name: "idx_rt_subj_rel_actor"
    add_index :rel_tuples,
      "tenant_id, subject, id, relation, actor, actor_id, COALESCE(actor_rel, ''::character varying)",
      unique: true, name: "uq_rt_fact"

    # Rename columns in service_grants table
    rename_column :service_grants, :ns, :subject
    rename_column :service_grants, :subject_ns, :actor
    rename_column :service_grants, :subject_prefix, :actor_prefix
    rename_column :service_grants, :object_prefix, :subject_prefix
  end
end
