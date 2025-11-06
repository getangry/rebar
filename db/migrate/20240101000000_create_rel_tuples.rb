class CreateRelTuples < ActiveRecord::Migration[7.1]
  def change
    create_table :rel_tuples, id: false do |t|
      t.bigserial :pk, primary_key: true
      t.string  :tenant_id, null: false, default: "default"
      t.string  :subject,   null: false
      t.string  :id,        null: false
      t.string  :relation,  null: false
      t.string  :actor,     null: false
      t.string  :actor_id,  null: false
      t.string  :actor_rel
      t.datetime :created_at, null: false, default: -> { "NOW()" }
    end

    add_index :rel_tuples, [:tenant_id, :subject, :id, :relation], name: "idx_rt_subj_rel"
    add_index :rel_tuples, [:tenant_id, :actor, :actor_id],  name: "idx_rt_actor"
    add_index :rel_tuples, [:tenant_id, :subject, :relation, :actor], name: "idx_rt_subj_rel_actor"

    add_index :rel_tuples,
      "tenant_id, subject, id, relation, actor, actor_id, COALESCE(actor_rel,'')",
      unique: true, name: "uq_rt_fact"
  end
end
