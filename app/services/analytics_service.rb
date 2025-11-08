class AnalyticsService
  ##
  # Record an analytics event
  #
  # @param event_type [String] Type of event (check, explain, create_tuple, etc.)
  # @param tenant_id [String] Tenant ID
  # @param service_id [String] Service ID (optional)
  # @param api_key_id [String] API Key ID (optional)
  # @param params [Hash] Event parameters
  # @param result [Boolean] Result of the operation (for permission checks)
  # @param latency_ms [Integer] Operation latency in milliseconds
  # @param ip_address [String] IP address of the requester
  # @param endpoint [String] API endpoint that was hit
  #
  def self.record_event(event_type:, tenant_id:, params: {}, **options)
    AnalyticsEvent.create!(
      event_type: event_type,
      tenant_id: tenant_id,
      service_id: options[:service_id],
      api_key_id: options[:api_key_id],
      actor: params[:actor],
      actor_id: params[:actor_id],
      permission: params[:permission],
      subject: params[:subject],
      subject_id: params[:subject_id],
      allowed: options[:result],
      latency_ms: options[:latency_ms],
      ip_address: options[:ip_address],
      endpoint: options[:endpoint],
      metadata: options[:metadata] || {}
    )
  rescue => e
    # Don't let analytics failures break the main request
    Rails.logger.error("Failed to record analytics event: #{e.message}")
    nil
  end

  ##
  # Get permission check metrics
  #
  # @param tenant_id [String] Tenant ID
  # @param since [Time] Start time for metrics
  # @param service_id [String] Optional service ID filter
  #
  def self.permission_metrics(tenant_id:, since: 24.hours.ago, service_id: nil)
    events = AnalyticsEvent.for_tenant(tenant_id)
                           .permission_checks
                           .since(since)

    events = events.for_service(service_id) if service_id.present?

    total_checks = events.count
    allowed_checks = events.allowed.count
    denied_checks = events.denied.count
    avg_latency = events.average(:latency_ms)&.to_f&.round(2) || 0.0

    {
      total_checks: total_checks,
      allowed_checks: allowed_checks,
      denied_checks: denied_checks,
      success_rate: total_checks > 0 ? ((allowed_checks.to_f / total_checks) * 100).round(2) : 0.0,
      avg_latency_ms: avg_latency,
      period: {
        start: since,
        end: Time.current
      }
    }
  end

  ##
  # Get most frequently checked permissions
  #
  # @param tenant_id [String] Tenant ID
  # @param since [Time] Start time for metrics
  # @param limit [Integer] Number of results to return
  #
  def self.top_permissions(tenant_id:, since: 24.hours.ago, limit: 10)
    AnalyticsEvent.for_tenant(tenant_id)
                  .permission_checks
                  .since(since)
                  .where.not(subject: nil, permission: nil)
                  .group(:subject, :permission)
                  .select('subject, permission, COUNT(*) as check_count,
                          SUM(CASE WHEN allowed THEN 1 ELSE 0 END) as allowed_count,
                          SUM(CASE WHEN NOT allowed THEN 1 ELSE 0 END) as denied_count')
                  .order('check_count DESC')
                  .limit(limit)
                  .map do |result|
      {
        subject: result.subject,
        permission: result.permission,
        total_checks: result.check_count,
        allowed: result.allowed_count,
        denied: result.denied_count,
        denial_rate: result.check_count > 0 ? ((result.denied_count.to_f / result.check_count) * 100).round(2) : 0
      }
    end
  end

  ##
  # Get failed access attempts patterns
  #
  # @param tenant_id [String] Tenant ID
  # @param since [Time] Start time for metrics
  # @param limit [Integer] Number of results to return
  #
  def self.failed_attempts(tenant_id:, since: 24.hours.ago, limit: 20)
    AnalyticsEvent.for_tenant(tenant_id)
                  .permission_checks
                  .denied
                  .since(since)
                  .group(:actor, :actor_id, :subject, :subject_id, :permission)
                  .select('actor, actor_id, subject, subject_id, permission,
                          COUNT(*) as attempt_count,
                          MAX(created_at) as last_attempt')
                  .order('attempt_count DESC')
                  .limit(limit)
                  .map do |result|
      {
        actor: result.actor,
        actor_id: result.actor_id,
        subject: result.subject,
        subject_id: result.subject_id,
        permission: result.permission,
        attempt_count: result.attempt_count,
        last_attempt: result.last_attempt
      }
    end
  end

  ##
  # Get service usage trends
  #
  # @param tenant_id [String] Tenant ID
  # @param since [Time] Start time for metrics
  #
  def self.service_usage(tenant_id:, since: 24.hours.ago)
    AnalyticsEvent.for_tenant(tenant_id)
                  .since(since)
                  .where.not(service_id: nil)
                  .group(:service_id)
                  .select('service_id,
                          COUNT(*) as total_requests,
                          AVG(latency_ms) as avg_latency,
                          COUNT(DISTINCT event_type) as event_types_count')
                  .order('total_requests DESC')
                  .map do |result|
      service = Service.find_by(id: result.service_id)
      {
        service_id: result.service_id,
        service_name: service&.name || 'Unknown',
        total_requests: result.total_requests,
        avg_latency_ms: result.avg_latency&.to_f&.round(2) || 0.0,
        event_types_count: result.event_types_count
      }
    end
  end

  ##
  # Get API key usage statistics
  #
  # @param tenant_id [String] Tenant ID
  # @param service_id [String] Optional service ID filter
  # @param since [Time] Start time for metrics
  #
  def self.api_key_usage(tenant_id:, service_id: nil, since: 24.hours.ago)
    events = AnalyticsEvent.for_tenant(tenant_id)
                           .since(since)
                           .where.not(api_key_id: nil)

    events = events.for_service(service_id) if service_id.present?

    events.group(:api_key_id)
          .select('api_key_id,
                  COUNT(*) as total_requests,
                  MAX(created_at) as last_used_at')
          .order('total_requests DESC')
          .map do |result|
      api_key = ApiKey.find_by(id: result.api_key_id)
      {
        api_key_id: result.api_key_id,
        api_key_name: api_key&.name || 'Unknown',
        key_prefix: api_key&.key_prefix,
        total_requests: result.total_requests,
        last_used_at: result.last_used_at
      }
    end
  end

  ##
  # Get time-series data for charts
  #
  # @param tenant_id [String] Tenant ID
  # @param since [Time] Start time for metrics
  # @param interval [String] Time interval (hour, day)
  #
  def self.time_series(tenant_id:, since: 24.hours.ago, interval: 'hour')
    interval_sql = case interval
                   when 'hour'
                     "date_trunc('hour', created_at)"
                   when 'day'
                     "date_trunc('day', created_at)"
                   else
                     "date_trunc('hour', created_at)"
                   end

    AnalyticsEvent.for_tenant(tenant_id)
                  .permission_checks
                  .since(since)
                  .group("#{interval_sql}, allowed")
                  .select("#{interval_sql} as time_bucket,
                          allowed,
                          COUNT(*) as count")
                  .order('time_bucket ASC')
                  .map do |result|
      {
        timestamp: result.time_bucket,
        allowed: result.allowed,
        count: result.count
      }
    end
  end
end
