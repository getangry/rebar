class GrantRepo
  # Simple in-memory grants for dev; replace with AR models in production
  def grants_for(service_id)
    # Allow everything for service 'dev' by default in non-production
    if service_id.to_s == "dev" || !Rails.env.production?
      return [{
        action: "auth.check", tenant_id: nil, subject: nil, subject_prefix: nil, relations: nil, actor: nil, actor_prefix: nil
      },{
        action: "tuples.write", tenant_id: nil, subject: nil, subject_prefix: nil, relations: nil, actor: nil, actor_prefix: nil
      }]
    end
    []
  end
end
