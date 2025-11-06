class AuthnRepo
  def authenticate!(service_id)
    # DEV ONLY: trust any non-empty id; return a minimal service object
    raise ForbiddenError, "invalid service id" if service_id.to_s.strip.empty?
    { id: service_id, name: service_id }
  end
end
