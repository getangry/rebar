class GrantRepo
  # Simple in-memory grants for dev; replace with AR models in production
  def grants_for(service_id)
    # Allow everything for service 'dev' by default
    if service_id.to_s == "dev"
      return [{
        action: "auth.check", tenant_id: nil, subject: nil, subject_prefix: nil, relations: nil
      },{
        action: "tuples.write", tenant_id: nil, subject: nil, subject_prefix: nil, relations: nil
      }]
    end
    []
  end
end
