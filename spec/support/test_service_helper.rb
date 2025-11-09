module TestServiceHelper
  def setup_test_service!(tenant: "default", name: "test-service")
    # Clean up any existing test services
    Service.where(name: name, tenant_id: tenant).destroy_all

    # Create test service with required schemas
    service = Service.create!(
      name: name,
      tenant_id: tenant,
      schemas: ["default"],
      description: "Test service for RSpec",
      active: true
    )

    # Get the auto-generated API key
    api_key = service.api_key

    # Return service and API key
    { service: service, api_key: api_key, service_id: service.id }
  end

  def test_auth_headers(api_key:, tenant: "default")
    {
      "Authorization" => "Bearer #{api_key}",
      "X-Tenant" => tenant,
      "Content-Type" => "application/json"
    }
  end
end

RSpec.configure do |config|
  config.include TestServiceHelper, type: :request
end
