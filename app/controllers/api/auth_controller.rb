module Api
  class AuthController < ::ApplicationController
    include ServiceAuth

    rescue_from ForbiddenError do |e|
      render json: { error: e.message }, status: :forbidden
    end

    def check
      gate.allow_check!(tenant: tenant, subject: p[:subject], subject_id: p[:subject_id], permission: p[:permission])
      ok = engine.check(p[:actor], p[:actor_id], p[:permission], p[:subject], p[:subject_id])
      render json: { allow: ok }
    end

    def explain
      gate.allow_check!(tenant: tenant, subject: p[:subject], subject_id: p[:subject_id], permission: p[:permission])
      path = engine.explain(p[:actor], p[:actor_id], p[:permission], p[:subject], p[:subject_id])
      if path
        render json: { allow: true, path: path }
      else
        render json: { allow: false }
      end
    end

    private

    def engine
      @engine ||= begin
        schema_index = Rails.root.join("schemas/index.rb")
        load schema_index # Load all schemas
        PermissionEngine.new(schema: AuthSchema, schema_name: schema_name, repo: RebacRepo.new(tenant_id: tenant))
      end
    end

    def schema_name
      # Schema name can come from service configuration or default to 'default'
      current_service&.dig(:schema_name) || 'default'
    end

    def tenant
      request.headers["X-Tenant"] || "default"
    end

    def p
      params.permit(:actor, :actor_id, :permission, :subject, :subject_id, :context)
    end
  end
end
