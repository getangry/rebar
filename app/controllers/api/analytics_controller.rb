module Api
  class AnalyticsController < ::ApplicationController
    include ServiceAuth

    # Skip authentication for analytics endpoints (accessible to all services in tenant)
    skip_before_action :authenticate_service!, only: [:metrics, :top_permissions, :failed_attempts, :service_usage, :api_key_usage, :time_series]

    # GET /api/analytics/metrics
    # Get overall permission check metrics
    def metrics
      since = parse_since_param
      service_id = params[:service_id]

      data = AnalyticsService.permission_metrics(
        tenant_id: tenant,
        since: since,
        service_id: service_id
      )

      render json: data
    end

    # GET /api/analytics/top_permissions
    # Get most frequently checked permissions
    def top_permissions
      since = parse_since_param
      limit = params[:limit]&.to_i || 10

      data = AnalyticsService.top_permissions(
        tenant_id: tenant,
        since: since,
        limit: limit
      )

      render json: { permissions: data }
    end

    # GET /api/analytics/failed_attempts
    # Get failed access attempts
    def failed_attempts
      since = parse_since_param
      limit = params[:limit]&.to_i || 20

      data = AnalyticsService.failed_attempts(
        tenant_id: tenant,
        since: since,
        limit: limit
      )

      render json: { attempts: data }
    end

    # GET /api/analytics/service_usage
    # Get service usage statistics
    def service_usage
      since = parse_since_param

      data = AnalyticsService.service_usage(
        tenant_id: tenant,
        since: since
      )

      render json: { services: data }
    end

    # GET /api/analytics/api_key_usage
    # Get API key usage statistics
    def api_key_usage
      since = parse_since_param
      service_id = params[:service_id]

      data = AnalyticsService.api_key_usage(
        tenant_id: tenant,
        service_id: service_id,
        since: since
      )

      render json: { api_keys: data }
    end

    # GET /api/analytics/time_series
    # Get time-series data for charts
    def time_series
      since = parse_since_param
      interval = params[:interval] || 'hour'

      data = AnalyticsService.time_series(
        tenant_id: tenant,
        since: since,
        interval: interval
      )

      render json: { data: data }
    end

    private

    def tenant
      request.headers["X-Tenant"] || "default"
    end

    def parse_since_param
      # Parse the 'since' parameter, default to 24 hours ago
      case params[:since]
      when '1h'
        1.hour.ago
      when '6h'
        6.hours.ago
      when '24h', '1d'
        24.hours.ago
      when '7d'
        7.days.ago
      when '30d'
        30.days.ago
      else
        if params[:since].present?
          Time.parse(params[:since]) rescue 24.hours.ago
        else
          24.hours.ago
        end
      end
    end
  end
end
