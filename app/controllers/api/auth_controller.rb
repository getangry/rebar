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
        schema_path = Rails.root.join("config/auth_schema.rb")
        load schema_path # Load the schema to ensure it's fresh
        PermissionEngine.new(schema: AuthSchema, repo: RebacRepo.new(tenant_id: tenant))
      end
    end

    def tenant
      request.headers["X-Tenant"] || "default"
    end

    def p
      params.permit(:actor, :actor_id, :permission, :subject, :subject_id, :context)
    end
  end
end
