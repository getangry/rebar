import { useState, useEffect } from 'react';
import { rebarClient } from '../api/rebar';
import type {
  AnalyticsMetrics,
  TopPermission,
  FailedAttempt,
  ServiceUsage,
  ApiKeyUsage,
} from '../api/rebar';
import Button from './ui/button';
import Badge from './ui/badge';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from './ui/table';
import { Alert, AlertDescription } from './ui/alert';

type TimePeriod = '1h' | '6h' | '24h' | '7d' | '30d';

export default function Analytics() {
  const [period, setPeriod] = useState<TimePeriod>('24h');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Analytics data
  const [metrics, setMetrics] = useState<AnalyticsMetrics | null>(null);
  const [topPermissions, setTopPermissions] = useState<TopPermission[]>([]);
  const [failedAttempts, setFailedAttempts] = useState<FailedAttempt[]>([]);
  const [serviceUsage, setServiceUsage] = useState<ServiceUsage[]>([]);
  const [apiKeyUsage, setApiKeyUsage] = useState<ApiKeyUsage[]>([]);

  useEffect(() => {
    loadAnalytics();
  }, [period]);

  const loadAnalytics = async () => {
    setLoading(true);
    setError(null);
    try {
      const [metricsData, permissionsData, attemptsData, servicesData, keysData] =
        await Promise.all([
          rebarClient.getAnalyticsMetrics({ since: period }),
          rebarClient.getTopPermissions({ since: period, limit: 10 }),
          rebarClient.getFailedAttempts({ since: period, limit: 20 }),
          rebarClient.getServiceUsage({ since: period }),
          rebarClient.getApiKeyUsage({ since: period }),
        ]);

      setMetrics(metricsData);
      setTopPermissions(permissionsData.permissions);
      setFailedAttempts(attemptsData.attempts);
      setServiceUsage(servicesData.services);
      setApiKeyUsage(keysData.api_keys);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load analytics');
    } finally {
      setLoading(false);
    }
  };

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleString();
  };

  const formatNumber = (num: number) => {
    return new Intl.NumberFormat().format(num);
  };

  const getPeriodLabel = (period: TimePeriod) => {
    const labels: Record<TimePeriod, string> = {
      '1h': 'Last Hour',
      '6h': 'Last 6 Hours',
      '24h': 'Last 24 Hours',
      '7d': 'Last 7 Days',
      '30d': 'Last 30 Days',
    };
    return labels[period];
  };

  return (
    <div className="px-4 sm:px-6 lg:px-8">
      <div className="mb-8">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-semibold text-gray-900">Analytics</h1>
            <p className="mt-2 text-sm text-gray-600">
              Monitor permission checks, service usage, and security insights
            </p>
          </div>
          <div className="flex gap-2 flex-wrap">
            {(['1h', '6h', '24h', '7d', '30d'] as TimePeriod[]).map((p) => (
              <Button
                key={p}
                onClick={() => setPeriod(p)}
                variant={period === p ? 'default' : 'outline'}
                size="sm"
                className="whitespace-nowrap"
              >
                {getPeriodLabel(p)}
              </Button>
            ))}
            <Button onClick={loadAnalytics} variant="outline" size="sm" className="whitespace-nowrap">
              Refresh
            </Button>
          </div>
        </div>
      </div>

      {error && (
        <Alert variant="destructive" className="mb-6">
          <AlertDescription>{error}</AlertDescription>
        </Alert>
      )}

      {loading ? (
        <div className="text-center py-8 text-gray-600">Loading analytics...</div>
      ) : (
        <div className="space-y-6">
          {/* Metrics Overview */}
          {metrics && (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-4">
              <div className="bg-white rounded-lg border border-gray-200 p-6">
                <div className="text-sm font-medium text-gray-600">Total Checks</div>
                <div className="mt-2 text-3xl font-semibold text-gray-900">
                  {formatNumber(metrics.total_checks)}
                </div>
              </div>

              <div className="bg-white rounded-lg border border-gray-200 p-6">
                <div className="text-sm font-medium text-gray-600">Allowed</div>
                <div className="mt-2 text-3xl font-semibold text-green-600">
                  {formatNumber(metrics.allowed_checks)}
                </div>
              </div>

              <div className="bg-white rounded-lg border border-gray-200 p-6">
                <div className="text-sm font-medium text-gray-600">Denied</div>
                <div className="mt-2 text-3xl font-semibold text-red-600">
                  {formatNumber(metrics.denied_checks)}
                </div>
              </div>

              <div className="bg-white rounded-lg border border-gray-200 p-6">
                <div className="text-sm font-medium text-gray-600">Success Rate</div>
                <div className="mt-2 text-3xl font-semibold text-blue-600">
                  {metrics.success_rate.toFixed(1)}%
                </div>
              </div>

              <div className="bg-white rounded-lg border border-gray-200 p-6">
                <div className="text-sm font-medium text-gray-600">Avg Latency</div>
                <div className="mt-2 text-3xl font-semibold text-purple-600">
                  {metrics.avg_latency_ms?.toFixed(0) || 0}ms
                </div>
              </div>
            </div>
          )}

          {/* Top Permissions */}
          <div className="bg-white rounded-lg border border-gray-200">
            <div className="px-6 py-4 border-b border-gray-200">
              <h2 className="text-lg font-semibold text-gray-900">
                Most Frequently Checked Permissions
              </h2>
            </div>
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Subject</TableHead>
                    <TableHead>Permission</TableHead>
                    <TableHead>Total Checks</TableHead>
                    <TableHead>Allowed</TableHead>
                    <TableHead>Denied</TableHead>
                    <TableHead>Denial Rate</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {topPermissions.length === 0 ? (
                    <TableRow>
                      <TableCell colSpan={6} className="text-center text-gray-500">
                        No permission checks recorded
                      </TableCell>
                    </TableRow>
                  ) : (
                    topPermissions.map((perm, idx) => (
                      <TableRow key={idx}>
                        <TableCell>
                          <code className="text-xs bg-gray-100 px-2 py-1 rounded">
                            {perm.subject}
                          </code>
                        </TableCell>
                        <TableCell>
                          <code className="text-xs bg-gray-100 px-2 py-1 rounded">
                            {perm.permission}
                          </code>
                        </TableCell>
                        <TableCell className="font-medium">
                          {formatNumber(perm.total_checks)}
                        </TableCell>
                        <TableCell className="text-green-600">
                          {formatNumber(perm.allowed)}
                        </TableCell>
                        <TableCell className="text-red-600">
                          {formatNumber(perm.denied)}
                        </TableCell>
                        <TableCell>
                          <Badge variant={perm.denial_rate > 50 ? 'destructive' : 'default'}>
                            {perm.denial_rate.toFixed(1)}%
                          </Badge>
                        </TableCell>
                      </TableRow>
                    ))
                  )}
                </TableBody>
              </Table>
            </div>
          </div>

          {/* Failed Access Attempts */}
          <div className="bg-white rounded-lg border border-gray-200">
            <div className="px-6 py-4 border-b border-gray-200">
              <h2 className="text-lg font-semibold text-gray-900">
                Failed Access Attempts
              </h2>
              <p className="text-sm text-gray-600">
                Patterns of denied permission checks - potential security concerns
              </p>
            </div>
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Actor</TableHead>
                    <TableHead>Subject</TableHead>
                    <TableHead>Permission</TableHead>
                    <TableHead>Attempts</TableHead>
                    <TableHead>Last Attempt</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {failedAttempts.length === 0 ? (
                    <TableRow>
                      <TableCell colSpan={5} className="text-center text-gray-500">
                        No failed attempts recorded
                      </TableCell>
                    </TableRow>
                  ) : (
                    failedAttempts.map((attempt, idx) => (
                      <TableRow key={idx}>
                        <TableCell>
                          <div className="font-mono text-xs">
                            <div className="text-gray-900">{attempt.actor}:{attempt.actor_id}</div>
                          </div>
                        </TableCell>
                        <TableCell>
                          <div className="font-mono text-xs">
                            <div className="text-gray-900">{attempt.subject}:{attempt.subject_id}</div>
                          </div>
                        </TableCell>
                        <TableCell>
                          <code className="text-xs bg-red-50 text-red-700 px-2 py-1 rounded">
                            {attempt.permission}
                          </code>
                        </TableCell>
                        <TableCell>
                          <Badge variant="destructive">{formatNumber(attempt.attempt_count)}</Badge>
                        </TableCell>
                        <TableCell className="text-sm text-gray-600">
                          {formatDate(attempt.last_attempt)}
                        </TableCell>
                      </TableRow>
                    ))
                  )}
                </TableBody>
              </Table>
            </div>
          </div>

          {/* Service Usage */}
          <div className="bg-white rounded-lg border border-gray-200">
            <div className="px-6 py-4 border-b border-gray-200">
              <h2 className="text-lg font-semibold text-gray-900">Service Usage</h2>
              <p className="text-sm text-gray-600">
                Request volume and performance by service
              </p>
            </div>
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Service Name</TableHead>
                    <TableHead>Total Requests</TableHead>
                    <TableHead>Avg Latency</TableHead>
                    <TableHead>Event Types</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {serviceUsage.length === 0 ? (
                    <TableRow>
                      <TableCell colSpan={4} className="text-center text-gray-500">
                        No service usage recorded
                      </TableCell>
                    </TableRow>
                  ) : (
                    serviceUsage.map((service) => (
                      <TableRow key={service.service_id}>
                        <TableCell className="font-medium text-gray-900">
                          {service.service_name}
                        </TableCell>
                        <TableCell>{formatNumber(service.total_requests)}</TableCell>
                        <TableCell>{service.avg_latency_ms?.toFixed(0) || 0}ms</TableCell>
                        <TableCell>
                          <Badge>{service.event_types_count}</Badge>
                        </TableCell>
                      </TableRow>
                    ))
                  )}
                </TableBody>
              </Table>
            </div>
          </div>

          {/* API Key Usage */}
          <div className="bg-white rounded-lg border border-gray-200">
            <div className="px-6 py-4 border-b border-gray-200">
              <h2 className="text-lg font-semibold text-gray-900">API Key Usage</h2>
              <p className="text-sm text-gray-600">
                Activity by API key across all services
              </p>
            </div>
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>API Key</TableHead>
                    <TableHead>Name</TableHead>
                    <TableHead>Total Requests</TableHead>
                    <TableHead>Last Used</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {apiKeyUsage.length === 0 ? (
                    <TableRow>
                      <TableCell colSpan={4} className="text-center text-gray-500">
                        No API key usage recorded
                      </TableCell>
                    </TableRow>
                  ) : (
                    apiKeyUsage.map((key) => (
                      <TableRow key={key.api_key_id}>
                        <TableCell>
                          <code className="text-xs bg-gray-100 px-2 py-1 rounded">
                            {key.key_prefix}
                          </code>
                        </TableCell>
                        <TableCell className="font-medium text-gray-900">
                          {key.api_key_name}
                        </TableCell>
                        <TableCell>{formatNumber(key.total_requests)}</TableCell>
                        <TableCell className="text-sm text-gray-600">
                          {formatDate(key.last_used_at)}
                        </TableCell>
                      </TableRow>
                    ))
                  )}
                </TableBody>
              </Table>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
