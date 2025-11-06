module Api
  class AuditLogsController < ::ApplicationController
    include ServiceAuth

    rescue_from ForbiddenError do |e|
      render json: { error: e.message }, status: :forbidden
    end

    # GET /audit_logs
    # Query audit logs with optional filters
    def index
      # Basic authorization check
      # In production, you'd want more granular permission checks here

      logs = AuditLog.for_tenant(tenant)

      # Apply filters
      logs = logs.for_service(params[:service_id]) if params[:service_id].present?
      # Note: Don't use params[:action] directly as it's reserved by Rails
      logs = logs.for_action(params[:action_type]) if params[:action_type].present?
      logs = logs.for_resource(params[:subject], params[:object_id]) if params[:subject].present? && params[:object_id].present?
      logs = logs.for_actor(params[:actor], params[:actor_id]) if params[:actor].present? && params[:actor_id].present?
      logs = logs.since(Time.parse(params[:since])) if params[:since].present?

      # Pagination
      page = (params[:page] || 1).to_i
      per_page = [(params[:per_page] || 50).to_i, 1000].min # Max 1000 per page

      logs = logs.recent.limit(per_page).offset((page - 1) * per_page)

      render json: {
        logs: logs.map { |log| format_log(log) },
        page: page,
        per_page: per_page
      }
    end

    # GET /audit_logs/:id
    # Get a specific audit log entry
    def show
      log = AuditLog.for_tenant(tenant).find(params[:id])
      render json: format_log(log)
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Audit log not found" }, status: :not_found
    end

    # GET /audit_logs/tuple_history
    # Get all audit logs for a specific tuple
    def tuple_history
      required_params = [:subject, :object_id, :relation, :actor, :actor_id]
      missing = required_params.select { |p| params[p].blank? }

      if missing.any?
        return render json: { error: "Missing required parameters: #{missing.join(', ')}" }, status: :bad_request
      end

      logs = AuditLog.tuple_history(
        tenant_id: tenant,
        subject: params[:subject],
        object_id: params[:object_id],
        relation: params[:relation],
        actor: params[:actor],
        actor_id: params[:actor_id]
      )

      render json: {
        tuple: {
          subject: params[:subject],
          object_id: params[:object_id],
          relation: params[:relation],
          actor: params[:actor],
          actor_id: params[:actor_id]
        },
        history: logs.map { |log| format_log(log) }
      }
    end

    # GET /audit_logs/stats
    # Get audit log statistics
    def stats
      logs = AuditLog.for_tenant(tenant)
      logs = logs.since(Time.parse(params[:since])) if params[:since].present?

      render json: {
        total_count: logs.count,
        by_action: logs.group(:action).count,
        by_service: logs.group(:service_id).count,
        by_resource_type: logs.group(:resource_type).count
      }
    end

    private

    def tenant
      request.headers["X-Tenant"] || "default"
    end

    def format_log(log)
      {
        id: log.id,
        tenant_id: log.tenant_id,
        service_id: log.service_id,
        actor_user_id: log.actor_user_id,
        ip_address: log.ip_address,
        action: log.action,
        resource_type: log.resource_type,
        tuple: {
          subject: log.subject,
          object_id: log.object_id,
          relation: log.relation,
          actor: log.actor,
          actor_id: log.actor_id,
          actor_rel: log.actor_rel
        }.compact,
        before_state: log.before_state,
        after_state: log.after_state,
        reason: log.reason,
        metadata: log.metadata,
        created_at: log.created_at,
        summary: log.to_summary
      }
    end
  end
end
