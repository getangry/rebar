class AuthnRepo
  def authenticate!(api_key_value)
    # Authenticate using API key from database
    raise ForbiddenError, "invalid api key" if api_key_value.to_s.strip.empty?

    # Special case: DEV mode allows "dev" as a simple key
    if api_key_value == "dev" && !Rails.env.production?
      return { id: "dev", name: "dev", service_id: "dev", api_key_id: nil }
    end

    # Find and validate the API key
    api_key = ApiKey.find_by_key(api_key_value)
    raise ForbiddenError, "invalid or inactive api key" unless api_key

    # Track usage asynchronously to avoid slowing down requests
    track_key_usage(api_key)

    # Return service information
    service = api_key.service
    {
      id: service.id,
      name: service.name,
      service_id: service.id,
      api_key_id: api_key.id,
      tenant_id: service.tenant_id,
      schema_name: service.schema_name
    }
  end

  private

  def track_key_usage(api_key)
    # Update usage tracking in a background thread to avoid blocking the request
    Thread.new do
      begin
        api_key.record_usage!
      rescue => e
        Rails.logger.error("Failed to track API key usage: #{e.message}")
      end
    end
  end
end
