module ServiceAuth
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_service!
  end

  def current_service
    @current_service
  end

  def gate
    @gate ||= PolicyGate.new(service_id: current_service[:id], grant_repo: GrantRepo.new)
  end

  def tenant
    request.headers["X-Tenant"] || "default"
  end

  private

  def authenticate_service!
    # Authenticate using standard Authorization: Bearer header
    auth_header = request.headers["Authorization"]
    raise ForbiddenError, "missing authorization header" if auth_header.blank?

    # Extract token from "Bearer <token>" format
    match = auth_header.match(/^Bearer\s+(.+)$/i)
    raise ForbiddenError, "invalid authorization format (expected: Bearer <token>)" unless match

    api_key = match[1]
    @current_service = AuthnRepo.new.authenticate!(api_key) # returns {id: ..., name: ..., service_id: ...}
  end
end
