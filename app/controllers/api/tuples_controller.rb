module Api
  class TuplesController < ::ApplicationController
    include ServiceAuth

    rescue_from ForbiddenError do |e|
      render json: { error: e.message }, status: :forbidden
    end

    def create
      gate.allow_tuple_write!(
        tenant: tenant,
        subject: p[:subject],
        id: p[:id],
        relation: p[:relation],
        actor: p[:actor],
        actor_id: p[:actor_id]
      )

      repo.write(
        subject: p[:subject],
        id: p[:id],
        relation: p[:relation],
        actor: p[:actor],
        actor_id: p[:actor_id],
        actor_rel: p[:actor_rel],
        reason: p[:reason]
      )

      # Create relationship attributes if provided
      if attributes_provided?
        tuple = find_created_tuple
        create_relationship_attributes(tuple.id) if tuple
      end

      render json: { ok: true }, status: :created
    end

    def destroy
      gate.allow_tuple_write!(
        tenant: tenant,
        subject: p[:subject],
        id: p[:id],
        relation: p[:relation],
        actor: p[:actor],
        actor_id: p[:actor_id]
      )

      repo.delete(
        subject: p[:subject],
        id: p[:id],
        relation: p[:relation],
        actor: p[:actor],
        actor_id: p[:actor_id],
        actor_rel: p[:actor_rel],
        reason: p[:reason]
      )

      render json: { ok: true }
    end

    def batch_create
      tuples = params[:tuples] || []

      tuples.each do |tuple|
        gate.allow_tuple_write!(
          tenant: tenant,
          subject: tuple[:subject],
          id: tuple[:id],
          relation: tuple[:relation],
          actor: tuple[:actor],
          actor_id: tuple[:actor_id]
        )
      end

      tuples.each do |tuple|
        repo.write(
          subject: tuple[:subject],
          id: tuple[:id],
          relation: tuple[:relation],
          actor: tuple[:actor],
          actor_id: tuple[:actor_id],
          actor_rel: tuple[:actor_rel],
          reason: tuple[:reason]
        )
      end

      render json: { ok: true, count: tuples.size }, status: :created
    end

    def batch_destroy
      tuples = params[:tuples] || []

      tuples.each do |tuple|
        gate.allow_tuple_write!(
          tenant: tenant,
          subject: tuple[:subject],
          id: tuple[:id],
          relation: tuple[:relation],
          actor: tuple[:actor],
          actor_id: tuple[:actor_id]
        )
      end

      tuples.each do |tuple|
        repo.delete(
          subject: tuple[:subject],
          id: tuple[:id],
          relation: tuple[:relation],
          actor: tuple[:actor],
          actor_id: tuple[:actor_id],
          actor_rel: tuple[:actor_rel],
          reason: tuple[:reason]
        )
      end

      render json: { ok: true, count: tuples.size }
    end

    private

    def repo
      RebacRepo.new(tenant: tenant, audit_logger: audit_logger)
    end

    def audit_logger
      @audit_logger ||= AuditLogger.new(
        tenant_id: tenant,
        service_id: request.headers["X-Service-Id"] || "unknown",
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      )
    end

    def tenant
      request.headers["X-Tenant"] || "default"
    end

    def p
      permitted = params.permit(:subject, :id, :subject_id, :relation, :actor, :actor_id, :actor_rel, :reason)

      # Support both 'id' and 'subject_id' parameters for backward compatibility
      # Prefer subject_id if both are provided
      if permitted[:subject_id].present?
        permitted[:id] = permitted[:subject_id]
      end

      permitted
    end

    def attributes_provided?
      params[:attributes].present? ||
      params[:valid_until].present? ||
      params[:max_usage].present? ||
      params[:approval_required].present? ||
      params[:requires_mfa].present?
    end

    def find_created_tuple
      RelTuple.find_by(
        tenant_id: tenant,
        actor: p[:actor],
        actor_id: p[:actor_id],
        relation: p[:relation],
        subject: p[:subject],
        subject_id: p[:id]
      )
    end

    def create_relationship_attributes(tuple_id)
      RelTupleAttribute.create_version!(
        tuple_id: tuple_id,
        attributes: params[:attributes] || {},
        tenant_id: tenant,
        created_by: "service:#{current_service[:id]}", # Use authenticated service
        usage_count: params[:usage_count]&.to_i,
        max_usage: params[:max_usage]&.to_i,
        granted_by: params[:granted_by],
        approval_required: params[:approval_required],
        approval_status: params[:approval_status] || (params[:approval_required] ? 'pending' : nil)
      )

      # Invalidate cache
      AttributeCache.invalidate_rel(tuple_id, tenant_id: tenant)
    rescue => e
      Rails.logger.error("Failed to create relationship attributes: #{e.message}")
      # Don't fail tuple creation if attributes fail
    end
  end
end
