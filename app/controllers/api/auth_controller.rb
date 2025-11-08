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
      start_time = Time.current
      parsed = parse_request_params
      gate.allow_check!(tenant: tenant, subject: parsed[:subject], subject_id: parsed[:subject_id], permission: parsed[:permission])
      ok = engine.check(parsed[:actor], parsed[:actor_id], parsed[:permission], parsed[:subject], parsed[:subject_id])

      # Record analytics
      record_analytics('check', parsed, ok, start_time)

      render json: { allow: ok }
    end

    def explain
      start_time = Time.current
      parsed = parse_request_params
      gate.allow_check!(tenant: tenant, subject: parsed[:subject], subject_id: parsed[:subject_id], permission: parsed[:permission])
      path = engine.explain(parsed[:actor], parsed[:actor_id], parsed[:permission], parsed[:subject], parsed[:subject_id])

      # Record analytics
      record_analytics('explain', parsed, path.present?, start_time)

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

    def record_analytics(event_type, params_hash, result, start_time)
      latency_ms = ((Time.current - start_time) * 1000).round

      AnalyticsService.record_event(
        event_type: event_type,
        tenant_id: tenant,
        service_id: current_service&.dig(:id),
        api_key_id: current_service&.dig(:api_key_id),
        params: params_hash,
        result: result,
        latency_ms: latency_ms,
        ip_address: request.remote_ip,
        endpoint: request.path
      )
    end
  end
end
