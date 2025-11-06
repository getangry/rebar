// Rebar API Client for TypeScript/React

export interface RelationshipTuple {
  subject: string;
  id: string;
  relation: string;
  actor: string;
  actor_id: string;
  actor_rel?: string;
}

export interface CheckPermissionRequest {
  actor: string;
  actor_id: string;
  permission: string;
  subject: string;
  subject_id: string;
}

export interface CheckPermissionResponse {
  allow: boolean;
}

export interface ExplainPermissionResponse {
  allow: boolean;
  path?: Array<Record<string, any>>;
}

export interface AuditLogTuple {
  subject?: string;
  object_id?: string;
  relation?: string;
  actor?: string;
  actor_id?: string;
  actor_rel?: string;
}

export interface AuditLog {
  id: number;
  tenant_id: string;
  service_id: string;
  actor_user_id?: string;
  ip_address?: string;
  action: string;
  resource_type: string;
  tuple: AuditLogTuple;
  before_state?: any;
  after_state?: any;
  reason?: string;
  metadata?: any;
  created_at: string;
  summary: string;
}

export interface AuditLogsResponse {
  logs: AuditLog[];
  page: number;
  per_page: number;
}

export interface AuditStatsResponse {
  total_count: number;
  by_action: Record<string, number>;
  by_service: Record<string, number>;
  by_resource_type: Record<string, number>;
}

export interface AuditLogFilters {
  service_id?: string;
  action_type?: string;
  subject?: string;
  object_id?: string;
  actor?: string;
  actor_id?: string;
  since?: string;
  page?: number;
  per_page?: number;
}

export class RebarClient {
  private serviceId: string;
  private tenant: string;
  private baseUrl: string;

  constructor(
    serviceId: string = "dev",
    tenant: string = "default",
    baseUrl: string = "" // Empty string uses current origin (proxy handles routing)
  ) {
    this.serviceId = serviceId;
    this.tenant = tenant;
    this.baseUrl = baseUrl;
  }

  private async request<T>(
    method: string,
    path: string,
    body?: any
  ): Promise<T> {
    const response = await fetch(`${this.baseUrl}${path}`, {
      method,
      headers: {
        "Content-Type": "application/json",
        "X-Service-Id": this.serviceId,
        "X-Tenant": this.tenant,
      },
      body: body ? JSON.stringify(body) : undefined,
    });

    if (!response.ok) {
      const error = await response
        .json()
        .catch(() => ({ error: response.statusText }));
      throw new Error(
        error.error || `HTTP ${response.status}: ${response.statusText}`
      );
    }

    return response.json();
  }

  // Create a relationship
  async createRelationship(tuple: RelationshipTuple): Promise<{ ok: boolean }> {
    return this.request("POST", "/api/tuples", tuple);
  }

  // Delete a relationship
  async deleteRelationship(tuple: RelationshipTuple): Promise<{ ok: boolean }> {
    return this.request("DELETE", "/api/tuples", tuple);
  }

  // Check if a permission is granted
  async checkPermission(req: CheckPermissionRequest): Promise<boolean> {
    const result = await this.request<CheckPermissionResponse>(
      "POST",
      "/api/auth/check",
      req
    );
    return result.allow;
  }

  // Explain why a permission is granted (or not)
  async explainPermission(
    req: CheckPermissionRequest
  ): Promise<ExplainPermissionResponse> {
    return this.request("POST", "/api/auth/explain", req);
  }

  // Batch create relationships
  async batchCreate(
    tuples: RelationshipTuple[]
  ): Promise<{ ok: boolean; count: number }> {
    return this.request("POST", "/api/tuples/batch", { tuples });
  }

  // Batch delete relationships
  async batchDelete(
    tuples: RelationshipTuple[]
  ): Promise<{ ok: boolean; count: number }> {
    return this.request("DELETE", "/api/tuples/batch", { tuples });
  }

  // Check API health
  async health(): Promise<any> {
    const response = await fetch(`${this.baseUrl}/up`);
    return response.text();
  }

  // Get audit logs with filters
  async getAuditLogs(filters?: AuditLogFilters): Promise<AuditLogsResponse> {
    const params = new URLSearchParams();
    if (filters) {
      Object.entries(filters).forEach(([key, value]) => {
        if (value !== undefined && value !== null) {
          params.append(key, value.toString());
        }
      });
    }
    const queryString = params.toString();
    const url = `/api/audit_logs${queryString ? `?${queryString}` : ""}`;

    const response = await fetch(`${this.baseUrl}${url}`, {
      headers: {
        "X-Service-Id": this.serviceId,
        "X-Tenant": this.tenant,
      },
    });

    if (!response.ok) {
      throw new Error(`Failed to fetch audit logs: ${response.statusText}`);
    }

    return response.json();
  }

  // Get a specific audit log
  async getAuditLog(id: number): Promise<AuditLog> {
    const response = await fetch(`${this.baseUrl}/api/audit_logs/${id}`, {
      headers: {
        "X-Service-Id": this.serviceId,
        "X-Tenant": this.tenant,
      },
    });

    if (!response.ok) {
      throw new Error(`Failed to fetch audit log: ${response.statusText}`);
    }

    return response.json();
  }

  // Get audit log statistics
  async getAuditStats(since?: string): Promise<AuditStatsResponse> {
    const params = new URLSearchParams();
    if (since) {
      params.append("since", since);
    }
    const queryString = params.toString();
    const url = `/api/audit_logs/stats${queryString ? `?${queryString}` : ""}`;

    const response = await fetch(`${this.baseUrl}${url}`, {
      headers: {
        "X-Service-Id": this.serviceId,
        "X-Tenant": this.tenant,
      },
    });

    if (!response.ok) {
      throw new Error(`Failed to fetch audit stats: ${response.statusText}`);
    }

    return response.json();
  }
}

// Default singleton instance
export const rebarClient = new RebarClient();
