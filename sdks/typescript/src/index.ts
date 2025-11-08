/**
 * Rebar ReBAC SDK for TypeScript/JavaScript
 *
 * Example usage:
 * ```typescript
 * import { RebarClient } from '@rebar/sdk';
 *
 * const client = new RebarClient({
 *   baseUrl: 'http://localhost:3000',
 *   serviceId: 'my-app',
 *   tenant: 'default'
 * });
 *
 * // Check permission
 * const allowed = await client.check({
 *   actor: 'user',
 *   actorId: 'alice',
 *   permission: 'can_edit',
 *   subject: 'doc',
 *   subjectId: 'doc-123'
 * });
 *
 * // Get actor permissions
 * const permissions = await client.getActorPermissions('user', 'alice');
 * ```
 */

export interface RebarClientConfig {
  baseUrl: string;
  serviceId: string;
  tenant?: string;
  timeout?: number;
}

export interface CheckRequest {
  actor: string;
  actorId: string;
  permission: string;
  subject: string;
  subjectId: string;
}

export interface CheckResponse {
  allow: boolean;
}

export interface ExplainResponse {
  allow: boolean;
  path?: any[];
}

export interface RelTuple {
  subject: string;
  id: string;
  relation: string;
  actor: string;
  actorId: string;
  actorRel?: string;
}

export interface Permission {
  permission: string;
  type: 'direct' | 'group' | 'inherited';
  via?: string;
}

export interface ResourcePermissions {
  resource: string;
  resourceType: string;
  resourceId: string;
  permissions: Permission[];
  actions: string[];
}

export interface ActorPermissionsResponse {
  actor: string;
  totalPermissions: number;
  directCount: number;
  groupCount: number;
  inheritedCount: number;
  groupMemberships: string[];
  resources: ResourcePermissions[];
}

export interface GroupMembership {
  group: string;
  groupId: string;
  role: string;
}

export interface ActorGroupsResponse {
  actor: string;
  memberships: GroupMembership[];
}

export interface AuditLog {
  id: number;
  tenantId: string;
  action: string;
  subject: string;
  subjectId: string;
  relation: string;
  actor: string;
  actorId: string;
  actorRel?: string;
  reason?: string;
  performedBy?: string;
  createdAt: string;
}

export interface AuditLogsResponse {
  logs: AuditLog[];
  total: number;
  page: number;
  perPage: number;
}

export class RebarClient {
  private baseUrl: string;
  private serviceId: string;
  private tenant: string;
  private timeout: number;

  constructor(config: RebarClientConfig) {
    this.baseUrl = config.baseUrl.replace(/\/$/, '');
    this.serviceId = config.serviceId;
    this.tenant = config.tenant || 'default';
    this.timeout = config.timeout || 10000;
  }

  /**
   * Check if an actor has a specific permission on a subject
   */
  async check(request: CheckRequest): Promise<boolean> {
    const response = await this.request<CheckResponse>('/api/auth/check', {
      method: 'POST',
      body: JSON.stringify({
        actor: request.actor,
        actor_id: request.actorId,
        permission: request.permission,
        subject: request.subject,
        subject_id: request.subjectId
      })
    });
    return response.allow;
  }

  /**
   * Check permission and get explanation path
   */
  async explain(request: CheckRequest): Promise<ExplainResponse> {
    return this.request<ExplainResponse>('/api/auth/explain', {
      method: 'POST',
      body: JSON.stringify({
        actor: request.actor,
        actor_id: request.actorId,
        permission: request.permission,
        subject: request.subject,
        subject_id: request.subjectId
      })
    });
  }

  /**
   * Create a relationship tuple
   */
  async createTuple(tuple: RelTuple): Promise<void> {
    await this.request('/api/tuples', {
      method: 'POST',
      body: JSON.stringify({
        subject: tuple.subject,
        id: tuple.id,
        relation: tuple.relation,
        actor: tuple.actor,
        actor_id: tuple.actorId,
        actor_rel: tuple.actorRel
      })
    });
  }

  /**
   * Delete a relationship tuple
   */
  async deleteTuple(tuple: RelTuple): Promise<void> {
    await this.request('/api/tuples', {
      method: 'DELETE',
      body: JSON.stringify({
        subject: tuple.subject,
        id: tuple.id,
        relation: tuple.relation,
        actor: tuple.actor,
        actor_id: tuple.actorId,
        actor_rel: tuple.actorRel
      })
    });
  }

  /**
   * Batch create relationship tuples
   */
  async batchCreateTuples(tuples: RelTuple[]): Promise<void> {
    await this.request('/api/tuples/batch', {
      method: 'POST',
      body: JSON.stringify({
        tuples: tuples.map(t => ({
          subject: t.subject,
          id: t.id,
          relation: t.relation,
          actor: t.actor,
          actor_id: t.actorId,
          actor_rel: t.actorRel
        }))
      })
    });
  }

  /**
   * Get all permissions for an actor
   */
  async getActorPermissions(actorType: string, actorId: string): Promise<ActorPermissionsResponse> {
    return this.request<ActorPermissionsResponse>(
      `/api/actors/${actorType}/${actorId}/permissions`
    );
  }

  /**
   * Get all groups an actor is a member of
   */
  async getActorGroups(actorType: string, actorId: string): Promise<ActorGroupsResponse> {
    return this.request<ActorGroupsResponse>(
      `/api/actors/${actorType}/${actorId}/groups`
    );
  }

  /**
   * Get audit logs
   */
  async getAuditLogs(params?: {
    page?: number;
    perPage?: number;
    subject?: string;
    actor?: string;
    action?: string;
  }): Promise<AuditLogsResponse> {
    const query = new URLSearchParams();
    if (params?.page) query.set('page', params.page.toString());
    if (params?.perPage) query.set('per_page', params.perPage.toString());
    if (params?.subject) query.set('subject', params.subject);
    if (params?.actor) query.set('actor', params.actor);
    if (params?.action) query.set('action', params.action);

    const url = `/api/audit_logs${query.toString() ? '?' + query.toString() : ''}`;
    return this.request<AuditLogsResponse>(url);
  }

  /**
   * Get schema information
   */
  async getSchema(): Promise<any> {
    return this.request('/api/schema');
  }

  /**
   * Change tenant for subsequent requests
   */
  setTenant(tenant: string): void {
    this.tenant = tenant;
  }

  /**
   * Internal request method
   */
  private async request<T = any>(path: string, init?: RequestInit): Promise<T> {
    const url = `${this.baseUrl}${path}`;

    const response = await fetch(url, {
      ...init,
      headers: {
        'Content-Type': 'application/json',
        'X-Service-Id': this.serviceId,
        'X-Tenant': this.tenant,
        ...init?.headers
      },
      signal: AbortSignal.timeout(this.timeout)
    });

    if (!response.ok) {
      const error = await response.json().catch(() => ({ error: response.statusText })) as { error?: string; message?: string };
      throw new Error(`Rebar API error: ${error.error || error.message || response.statusText}`);
    }

    return response.json() as Promise<T>;
  }
}

// React hook for easy integration
export function useRebarClient(config: RebarClientConfig) {
  const client = new RebarClient(config);
  return client;
}
