class AuditLogger
  def initialize(
    tenant_id:,
    service_id:,
    ip_address: nil,
    user_agent: nil,
    actor_user_id: nil
  )
    @tenant_id = tenant_id
    @service_id = service_id
    @ip_address = ip_address
    @user_agent = user_agent
    @actor_user_id = actor_user_id
  end

  # Log a tuple creation
  def log_create(subject:, id:, relation:, actor:, actor_id:, actor_rel: nil, reason: nil, metadata: {})
    create_log(
      action: "create",
      resource_type: "rel_tuple",
      subject: subject,
      object_id: id,
      relation: relation,
      actor: actor,
      actor_id: actor_id,
      actor_rel: actor_rel,
      after_state: build_tuple_state(subject, id, relation, actor, actor_id, actor_rel),
      reason: reason,
      metadata: metadata
    )
  end

  # Log a tuple deletion
  def log_delete(subject:, id:, relation:, actor:, actor_id:, actor_rel: nil, reason: nil, metadata: {})
    create_log(
      action: "delete",
      resource_type: "rel_tuple",
      subject: subject,
      object_id: id,
      relation: relation,
      actor: actor,
      actor_id: actor_id,
      actor_rel: actor_rel,
      before_state: build_tuple_state(subject, id, relation, actor, actor_id, actor_rel),
      reason: reason,
      metadata: metadata
    )
  end

  # Log a tuple update (if we ever support updates)
  def log_update(
    subject:, id:, relation:, actor:, actor_id:,
    before:, after:,
    reason: nil, metadata: {}
  )
    create_log(
      action: "update",
      resource_type: "rel_tuple",
      subject: subject,
      object_id: id,
      relation: relation,
      actor: actor,
      actor_id: actor_id,
      before_state: before,
      after_state: after,
      reason: reason,
      metadata: metadata
    )
  end

  # Log a batch operation
  def log_batch(action:, count:, resource_type: "rel_tuple", reason: nil, metadata: {})
    create_log(
      action: "batch_#{action}",
      resource_type: resource_type,
      reason: reason,
      metadata: metadata.merge(count: count)
    )
  end

  private

  def create_log(attributes)
    AuditLog.create!(
      tenant_id: @tenant_id,
      service_id: @service_id,
      ip_address: @ip_address,
      user_agent: @user_agent,
      actor_user_id: @actor_user_id,
      **attributes
    )
  rescue => e
    # Don't let audit logging failure break the main operation
    # Log to Rails logger instead
    Rails.logger.error("Failed to create audit log: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    nil
  end

  def build_tuple_state(subject, id, relation, actor, actor_id, actor_rel)
    {
      subject: subject,
      id: id,
      relation: relation,
      actor: actor,
      actor_id: actor_id,
      actor_rel: actor_rel
    }.compact
  end
end
