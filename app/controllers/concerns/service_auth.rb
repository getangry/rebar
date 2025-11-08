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
    # DEV ONLY: X-Service-Id header; replace with mTLS/JWT in prod.
    sid = request.headers["X-Service-Id"]
    raise ForbiddenError, "missing service id" if sid.blank?
    @current_service = AuthnRepo.new.authenticate!(sid) # returns {id: ..., name: ...}
  end
end
