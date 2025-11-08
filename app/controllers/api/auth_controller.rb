module Api
  class AuthController < ::ApplicationController
    include ServiceAuth

    rescue_from ForbiddenError do |e|
      render json: { error: e.message }, status: :forbidden
    end

    rescue_from TupleParser::ParseError do |e|
      render json: { error: "Invalid tuple format: #{e.message}" }, status: :unprocessable_entity
    end

    def check
      parsed = parse_request_params
      gate.allow_check!(tenant: tenant, subject: parsed[:subject], subject_id: parsed[:subject_id], permission: parsed[:permission])
      ok = engine.check(parsed[:actor], parsed[:actor_id], parsed[:permission], parsed[:subject], parsed[:subject_id])
      render json: { allow: ok }
    end

    def explain
      parsed = parse_request_params
      gate.allow_check!(tenant: tenant, subject: parsed[:subject], subject_id: parsed[:subject_id], permission: parsed[:permission])
      path = engine.explain(parsed[:actor], parsed[:actor_id], parsed[:permission], parsed[:subject], parsed[:subject_id])
      if path
        render json: { allow: true, path: path }
      else
        render json: { allow: false }
      end
    end

    private

    def parse_request_params
      # Support both tuple format and traditional JSON format
      if params[:tuple].present?
        TupleParser.parse(params[:tuple])
      else
        p
      end
    end

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
