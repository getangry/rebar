class RebacRepo
  def initialize(conn: ActiveRecord::Base.connection, tenant: "default", tenant_id: nil)
    @conn = conn
    @tenant_id = tenant_id || tenant
  end

  def write(subject:, id:, relation:, actor:, actor_id:, actor_rel: nil)
    @conn.exec_insert(<<~SQL, "rel_tuples.write", [@tenant_id, subject, id, relation, actor, actor_id, actor_rel])
      INSERT INTO rel_tuples (tenant_id, subject, id, relation, actor, actor_id, actor_rel)
      VALUES ($1,$2,$3,$4,$5,$6,$7)
      ON CONFLICT (tenant_id, subject, id, relation, actor, actor_id, COALESCE(actor_rel, '')) DO NOTHING
    SQL
  end

  def delete(subject:, id:, relation:, actor:, actor_id:, actor_rel: nil)
    @conn.exec_delete(<<~SQL, "rel_tuples.delete", [@tenant_id, subject, id, relation, actor, actor_id, actor_rel])
      DELETE FROM rel_tuples
      WHERE tenant_id=$1 AND subject=$2 AND id=$3 AND relation=$4
        AND actor=$5 AND actor_id=$6 AND COALESCE(actor_rel,'')=COALESCE($7,'')
    SQL
  end

  def edges_for_object(subject:, id:, relation:)
    @conn.exec_query(<<~SQL, "rel_tuples.by_obj_rel", [@tenant_id, subject, id, relation]).to_a
      SELECT actor, actor_id, actor_rel
      FROM rel_tuples
      WHERE tenant_id=$1 AND subject=$2 AND id=$3 AND relation=$4
    SQL
  end

  def parents_of(subject:, id:)
    @conn.exec_query(<<~SQL, "rel_tuples.parents", [@tenant_id, subject, id]).to_a
      SELECT actor AS subject, actor_id AS id
      FROM rel_tuples
      WHERE tenant_id=$1 AND subject=$2 AND id=$3 AND relation='parent'
    SQL
  end

  def expand_group_members(group_type:, group_id:)
    @conn.exec_query(<<~SQL, "rel_tuples.group_closure", [@tenant_id, group_type, group_id]).to_a
      WITH RECURSIVE m(subj_type, id) AS (
        SELECT actor, actor_id
        FROM rel_tuples
        WHERE tenant_id=$1 AND subject=$2 AND id=$3 AND relation='member'
      UNION
        SELECT rt.actor, rt.actor_id
        FROM rel_tuples rt
        JOIN m ON rt.tenant_id=$1 AND rt.subject = m.subj_type AND rt.id = m.id
        WHERE rt.relation='member' AND rt.actor !='user'
      )
      SELECT DISTINCT subj_type AS subject, id FROM m WHERE subj_type='user'
    SQL
  end
end
