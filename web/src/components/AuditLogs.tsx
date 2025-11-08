import { useState, useEffect } from 'react';
import { rebarClient } from '../api/rebar';
import type { AuditLog, AuditLogFilters, AuditStatsResponse } from '../api/rebar';
import Button from './ui/button';
import Badge from './ui/badge';
import { InputGroup, SelectGroup } from './ui/input-group';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from './ui/table';
import Drawer from './ui/drawer';
import StatsCard from './ui/stats-card';
import { Alert, AlertDescription } from './ui/alert';

export default function AuditLogs() {
  const [logs, setLogs] = useState<AuditLog[]>([]);
  const [stats, setStats] = useState<AuditStatsResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [selectedLog, setSelectedLog] = useState<AuditLog | null>(null);

  // Pagination
  const [currentPage, setCurrentPage] = useState(1);
  const [perPage, setPerPage] = useState(50);

  // Sorting
  const [sortBy, setSortBy] = useState<string>('created_at');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('desc');

  // Filters
  const [filters, setFilters] = useState<AuditLogFilters>({
    page: 1,
    per_page: 50,
    sort_by: 'created_at',
    sort_order: 'desc',
  });
  const [tempFilters, setTempFilters] = useState<AuditLogFilters>({});

  useEffect(() => {
    loadLogs();
    loadStats();
  }, [filters]);

  const loadLogs = async () => {
    setLoading(true);
    setError(null);
    try {
      const response = await rebarClient.getAuditLogs(filters);
      setLogs(response.logs);
      setCurrentPage(response.page);
      setPerPage(response.per_page);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load audit logs');
    } finally {
      setLoading(false);
    }
  };

  const loadStats = async () => {
    try {
      const statsData = await rebarClient.getAuditStats(filters.since);
      setStats(statsData);
    } catch (err) {
      console.error('Failed to load stats:', err);
    }
  };

  const applyFilters = () => {
    setFilters({
      ...tempFilters,
      page: 1,
      per_page: perPage,
    });
  };

  const clearFilters = () => {
    setTempFilters({});
    setFilters({ page: 1, per_page: perPage });
  };

  const nextPage = () => {
    setFilters({ ...filters, page: currentPage + 1 });
  };

  const prevPage = () => {
    if (currentPage > 1) {
      setFilters({ ...filters, page: currentPage - 1 });
    }
  };

  const handleSort = (column: string) => {
    const newSortOrder = sortBy === column && sortOrder === 'desc' ? 'asc' : 'desc';
    setSortBy(column);
    setSortOrder(newSortOrder);
    setFilters({
      ...filters,
      page: 1,
      sort_by: column,
      sort_order: newSortOrder,
    });
  };

  const getSortIcon = (column: string) => {
    if (sortBy !== column) {
      return '↕️';
    }
    return sortOrder === 'desc' ? '↓' : '↑';
  };

  const formatDate = (dateString: string) => {
    const date = new Date(dateString);
    return date.toLocaleString();
  };

  const getActionVariant = (action: string): 'success' | 'destructive' | 'warning' | 'default' => {
    switch (action) {
      case 'create':
        return 'success';
      case 'delete':
        return 'destructive';
      case 'update':
        return 'warning';
      default:
        return 'default';
    }
  };

  const getActionIcon = (action: string) => {
    switch (action) {
      case 'create':
        return '➕';
      case 'delete':
        return '🗑️';
      case 'update':
        return '✏️';
      default:
        return '📝';
    }
  };

  return (
    <div className="px-4 sm:px-6 lg:px-8">
      {/* Page header */}
      <div className="mb-8">
        <h1 className="text-2xl font-semibold text-gray-900">Audit Logs</h1>
        <p className="mt-2 text-sm text-gray-600">
          A complete history of all changes to relationship tuples in your system.
        </p>
      </div>

      {/* Stats */}
      {stats && (
        <div className="mb-8">
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
            <StatsCard
              name="Total Events"
              value={stats.total_count.toLocaleString()}
              icon={
                <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" strokeWidth="1.5" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M3.75 3v11.25A2.25 2.25 0 006 16.5h2.25M3.75 3h-1.5m1.5 0h16.5m0 0h1.5m-1.5 0v11.25A2.25 2.25 0 0118 16.5h-2.25m-7.5 0h7.5m-7.5 0l-1 3m8.5-3l1 3m0 0l.5 1.5m-.5-1.5h-9.5m0 0l-.5 1.5M9 11.25v1.5M12 9v3.75m3-6v6" />
                </svg>
              }
            />
            {Object.entries(stats.by_action).map(([action, count]) => (
              <StatsCard
                key={action}
                name={`${getActionIcon(action)} ${action.charAt(0).toUpperCase() + action.slice(1)}`}
                value={count.toLocaleString()}
              />
            ))}
          </div>
        </div>
      )}

      {/* Filters */}
      <div className="mb-8 bg-white rounded-lg border border-gray-200 p-6">
        <h3 className="text-base font-semibold text-gray-900 mb-6">Filters</h3>
        <div className="grid grid-cols-1 gap-x-6 gap-y-6 sm:grid-cols-2 lg:grid-cols-3">
          <SelectGroup
            label="Action"
            id="action"
            value={tempFilters.action_type || ''}
            onChange={(e) => setTempFilters({ ...tempFilters, action_type: e.target.value || undefined })}
          >
            <option value="">All Actions</option>
            <option value="create">Create</option>
            <option value="delete">Delete</option>
            <option value="update">Update</option>
          </SelectGroup>

          <InputGroup
            label="Service ID"
            id="service_id"
            placeholder="e.g., dev, api-service"
            value={tempFilters.service_id || ''}
            onChange={(e) => setTempFilters({ ...tempFilters, service_id: e.target.value || undefined })}
          />

          <InputGroup
            label="Subject"
            id="subject"
            placeholder="e.g., doc, folder"
            value={tempFilters.subject || ''}
            onChange={(e) => setTempFilters({ ...tempFilters, subject: e.target.value || undefined })}
          />

          <InputGroup
            label="Relation"
            id="relation"
            placeholder="e.g., editor, viewer, owner"
            value={tempFilters.relation || ''}
            onChange={(e) => setTempFilters({ ...tempFilters, relation: e.target.value || undefined })}
          />

          <InputGroup
            label="Actor"
            id="actor"
            placeholder="e.g., user, group"
            value={tempFilters.actor || ''}
            onChange={(e) => setTempFilters({ ...tempFilters, actor: e.target.value || undefined })}
          />

          <InputGroup
            label="Actor ID"
            id="actor_id"
            placeholder="e.g., alice, bob"
            value={tempFilters.actor_id || ''}
            onChange={(e) => setTempFilters({ ...tempFilters, actor_id: e.target.value || undefined })}
          />

          <InputGroup
            label="Since Date"
            id="since"
            type="datetime-local"
            value={tempFilters.since || ''}
            onChange={(e) => setTempFilters({ ...tempFilters, since: e.target.value ? new Date(e.target.value).toISOString() : undefined })}
          />
        </div>

        <div className="mt-6 flex items-center gap-x-3">
          <Button onClick={applyFilters} variant="default">
            Apply Filters
          </Button>
          <Button onClick={clearFilters} variant="secondary">
            Clear
          </Button>
        </div>
      </div>

      {/* Error */}
      {error && (
        <div className="mb-8">
          <Alert variant="destructive">
            <AlertDescription>{error}</AlertDescription>
          </Alert>
        </div>
      )}

      {/* Loading */}
      {loading && (
        <div className="text-center py-12">
          <div className="inline-flex items-center text-sm text-gray-600">
            <svg className="animate-spin -ml-1 mr-3 h-5 w-5 text-gray-400" fill="none" viewBox="0 0 24 24">
              <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
              <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            Loading audit logs...
          </div>
        </div>
      )}

      {/* Empty state */}
      {!loading && logs.length === 0 && (
        <div className="text-center py-12 bg-white rounded-lg border border-gray-200">
          <svg className="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
          </svg>
          <h3 className="mt-4 text-sm font-medium text-gray-900">No audit logs found</h3>
          <p className="mt-2 text-sm text-gray-500">Try adjusting your filters to see more results.</p>
        </div>
      )}

      {/* Table */}
      {!loading && logs.length > 0 && (
        <div>
          <div className="overflow-hidden bg-white rounded-lg border border-gray-200">
            <Table>
              <TableHeader>
                <TableRow className="border-b border-gray-200">
                  <TableHead
                    className="bg-gray-50 py-3.5 text-left text-sm font-semibold text-gray-900 cursor-pointer hover:bg-gray-100"
                    onClick={() => handleSort('created_at')}
                  >
                    Timestamp {getSortIcon('created_at')}
                  </TableHead>
                  <TableHead
                    className="bg-gray-50 py-3.5 text-left text-sm font-semibold text-gray-900 cursor-pointer hover:bg-gray-100"
                    onClick={() => handleSort('action')}
                  >
                    Action {getSortIcon('action')}
                  </TableHead>
                  <TableHead className="bg-gray-50 py-3.5 text-left text-sm font-semibold text-gray-900">
                    <div className="flex flex-col gap-1">
                      <button
                        onClick={() => handleSort('subject')}
                        className="text-left hover:text-gray-600 transition-colors"
                      >
                        Subject {getSortIcon('subject')}
                      </button>
                      <button
                        onClick={() => handleSort('relation')}
                        className="text-left text-xs font-normal text-gray-600 hover:text-gray-900 transition-colors"
                      >
                        Relation {getSortIcon('relation')}
                      </button>
                    </div>
                  </TableHead>
                  <TableHead
                    className="bg-gray-50 py-3.5 text-left text-sm font-semibold text-gray-900 cursor-pointer hover:bg-gray-100"
                    onClick={() => handleSort('actor')}
                  >
                    Actor {getSortIcon('actor')}
                  </TableHead>
                  <TableHead
                    className="bg-gray-50 py-3.5 text-left text-sm font-semibold text-gray-900 cursor-pointer hover:bg-gray-100"
                    onClick={() => handleSort('service_id')}
                  >
                    Service {getSortIcon('service_id')}
                  </TableHead>
                  <TableHead className="bg-gray-50 py-3.5 text-left text-sm font-semibold text-gray-900">Reason</TableHead>
                  <TableHead className="bg-gray-50 relative py-3.5">
                    <span className="sr-only">View</span>
                  </TableHead>
                </TableRow>
              </TableHeader>
              <TableBody className="bg-white divide-y divide-gray-100">
                {logs.map((log) => (
                  <TableRow key={log.id} className="hover:bg-gray-50">
                    <TableCell className="whitespace-nowrap py-4 text-sm text-gray-500">
                      {formatDate(log.created_at)}
                    </TableCell>
                    <TableCell className="whitespace-nowrap py-4">
                      <Badge variant={getActionVariant(log.action)}>
                        {getActionIcon(log.action)} {log.action}
                      </Badge>
                    </TableCell>
                    <TableCell className="py-4 text-sm">
                      {log.tuple.subject && log.tuple.object_id && (
                        <div>
                          <div className="font-medium text-gray-900">
                            {log.tuple.subject}:{log.tuple.object_id}
                          </div>
                          {log.tuple.relation && (
                            <div className="text-gray-500 font-mono text-xs mt-1">
                              {log.tuple.relation}
                            </div>
                          )}
                        </div>
                      )}
                    </TableCell>
                    <TableCell className="whitespace-nowrap py-4 text-sm font-mono text-gray-900">
                      {log.tuple.actor && log.tuple.actor_id && (
                        <span>{log.tuple.actor}:{log.tuple.actor_id}</span>
                      )}
                    </TableCell>
                    <TableCell className="whitespace-nowrap py-4 text-sm text-gray-500">
                      {log.service_id}
                    </TableCell>
                    <TableCell className="py-4 text-sm text-gray-500 max-w-xs">
                      {log.reason ? (
                        <span className="block truncate" title={log.reason}>
                          {log.reason}
                        </span>
                      ) : (
                        <span className="text-gray-300">—</span>
                      )}
                    </TableCell>
                    <TableCell className="relative whitespace-nowrap py-4 text-right text-sm">
                      <button
                        onClick={() => setSelectedLog(log)}
                        className="text-gray-600 hover:text-gray-900 font-medium"
                      >
                        View
                      </button>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>

          {/* Pagination */}
          <div className="mt-6 flex items-center justify-between">
            <div className="text-sm text-gray-600">
              Page <span className="font-medium">{currentPage}</span> · {' '}
              <span className="font-medium">{logs.length}</span> results
            </div>
            <div className="flex gap-3">
              <Button
                onClick={prevPage}
                disabled={currentPage === 1}
                variant="outline"
                size="sm"
              >
                Previous
              </Button>
              <Button
                onClick={nextPage}
                disabled={logs.length < perPage}
                variant="outline"
                size="sm"
              >
                Next
              </Button>
            </div>
          </div>
        </div>
      )}

      {/* Detail Drawer */}
      <Drawer
        open={!!selectedLog}
        onClose={() => setSelectedLog(null)}
        title="Audit Log Details"
      >
        {selectedLog && (
          <div className="space-y-8">
            <div>
              <h3 className="text-sm font-semibold text-gray-900 mb-4">Overview</h3>
              <dl className="space-y-3">
                <div className="flex justify-between text-sm">
                  <dt className="text-gray-600">ID</dt>
                  <dd className="text-gray-900 font-medium">{selectedLog.id}</dd>
                </div>
                <div className="flex justify-between text-sm">
                  <dt className="text-gray-600">Timestamp</dt>
                  <dd className="text-gray-900 font-medium">{formatDate(selectedLog.created_at)}</dd>
                </div>
                <div className="flex justify-between text-sm">
                  <dt className="text-gray-600">Action</dt>
                  <dd>
                    <Badge variant={getActionVariant(selectedLog.action)}>
                      {getActionIcon(selectedLog.action)} {selectedLog.action}
                    </Badge>
                  </dd>
                </div>
                <div className="flex justify-between text-sm">
                  <dt className="text-gray-600">Service ID</dt>
                  <dd className="text-gray-900 font-medium">{selectedLog.service_id}</dd>
                </div>
                <div className="flex justify-between text-sm">
                  <dt className="text-gray-600">Tenant ID</dt>
                  <dd className="text-gray-900 font-medium">{selectedLog.tenant_id}</dd>
                </div>
                {selectedLog.ip_address && (
                  <div className="flex justify-between text-sm">
                    <dt className="text-gray-600">IP Address</dt>
                    <dd className="text-gray-900 font-mono font-medium">{selectedLog.ip_address}</dd>
                  </div>
                )}
                {selectedLog.reason && (
                  <div>
                    <dt className="text-sm text-gray-600 mb-2">Reason</dt>
                    <dd className="text-sm text-gray-900">{selectedLog.reason}</dd>
                  </div>
                )}
              </dl>
            </div>

            <div>
              <h3 className="text-sm font-semibold text-gray-900 mb-3">Tuple Data</h3>
              <pre className="overflow-auto rounded-lg bg-gray-50 border border-gray-200 p-4 text-xs text-gray-900">
                {JSON.stringify(selectedLog.tuple, null, 2)}
              </pre>
            </div>

            {selectedLog.before_state && (
              <div>
                <h3 className="text-sm font-semibold text-gray-900 mb-3">Before State</h3>
                <pre className="overflow-auto rounded-lg bg-yellow-50 border border-yellow-200 p-4 text-xs text-gray-900">
                  {JSON.stringify(selectedLog.before_state, null, 2)}
                </pre>
              </div>
            )}

            {selectedLog.after_state && (
              <div>
                <h3 className="text-sm font-semibold text-gray-900 mb-3">After State</h3>
                <pre className="overflow-auto rounded-lg bg-green-50 border border-green-200 p-4 text-xs text-gray-900">
                  {JSON.stringify(selectedLog.after_state, null, 2)}
                </pre>
              </div>
            )}

            <div>
              <h3 className="text-sm font-semibold text-gray-900 mb-3">Summary</h3>
              <div className="rounded-lg bg-blue-50 border border-blue-200 p-4 text-sm font-mono text-gray-900">
                {selectedLog.summary}
              </div>
            </div>
          </div>
        )}
      </Drawer>
    </div>
  );
}
