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
        actor_rel: p[:actor_rel]
      )

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
        actor_rel: p[:actor_rel]
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
          actor_rel: tuple[:actor_rel]
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
          actor_rel: tuple[:actor_rel]
        )
      end

      render json: { ok: true, count: tuples.size }
    end

    private

    def repo
      RebacRepo.new(tenant: tenant)
    end

    def tenant
      request.headers["X-Tenant"] || "default"
    end

    def p
      params.permit(:subject, :id, :relation, :actor, :actor_id, :actor_rel)
    end
  end
end
