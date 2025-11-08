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
  id: string;
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

export interface SchemaStats {
  as_subject: number;
  as_actor: number;
  total: number;
  relations: string[];
}

export interface SchemaInfo {
  name: string;
  purpose: string;
  type_count?: number;
}

export interface SchemaResponse {
  current_schema?: SchemaInfo;
  available_schemas?: SchemaInfo[];
  types: Record<string, {
    relations?: Record<string, string[]>;
  }>;
  stats: Record<string, SchemaStats>;
}

export interface GraphNode {
  id: string;
  type: string;
  object_id: string | number;
  label: string;
  relations: string[];
}

export interface GraphEdge {
  source: string;
  target: string;
  relation: string;
  actor_rel?: string;
}

export interface GraphResponse {
  nodes: GraphNode[];
  edges: GraphEdge[];
  node_count: number;
  edge_count: number;
  center_entity?: string;
}

export interface Entity {
  id: string;
  type: string;
  object_id: string | number;
}

export interface EntitiesResponse {
  entities: Record<string, Entity[]>;
}

export interface Permission {
  permission: string;
  type: 'direct' | 'group' | 'inherited';
  via?: string;
}

export interface ResourcePermissions {
  resource: string;
  resource_type: string;
  resource_id: string;
  permissions: Permission[];
  actions: string[];
}

export interface ActorPermissionsResponse {
  actor: string;
  total_permissions: number;
  direct_count: number;
  group_count: number;
  inherited_count: number;
  group_memberships: string[];
  resources: ResourcePermissions[];
}

export interface GroupMembership {
  group: string;
  group_id: string;
  role: string;
}

export interface ActorGroupsResponse {
  actor: string;
  memberships: GroupMembership[];
}

export interface AuditLogFilters {
  service_id?: string;
  action_type?: string;
  subject?: string;
  object_id?: string;
  relation?: string;
  actor?: string;
  actor_id?: string;
  since?: string;
  page?: number;
  per_page?: number;
  sort_by?: string;
  sort_order?: 'asc' | 'desc';
}

export interface ApiKey {
  id: string;
  name?: string;
  key_prefix: string;
  active: boolean;
  last_used_at?: string;
  usage_count: number;
  created_at: string;
}

export interface Service {
  id: string;
  name: string;
  description?: string;
  schemas: string[];
  active: boolean;
  tenant_id: string;
  allowed_subjects: string[];
  allowed_relations: string[];
  metadata: Record<string, any>;
  created_at: string;
  updated_at: string;
  api_keys: ApiKey[];
  api_key?: string; // Only present on creation/regeneration
}

export interface CreateServiceRequest {
  name: string;
  description?: string;
  schemas?: string[];
  active?: boolean;
  allowed_subjects?: string[];
  allowed_relations?: string[];
  metadata?: Record<string, any>;
}

export interface ServicesResponse {
  services: Service[];
}

export interface RegenerateKeyResponse {
  message: string;
  api_key: string;
  service: Service;
}

// Analytics interfaces
export interface AnalyticsMetrics {
  total_checks: number;
  allowed_checks: number;
  denied_checks: number;
  success_rate: number;
  avg_latency_ms: number;
  period: {
    start: string;
    end: string;
  };
}

export interface TopPermission {
  subject: string;
  permission: string;
  total_checks: number;
  allowed: number;
  denied: number;
  denial_rate: number;
}

export interface TopPermissionsResponse {
  permissions: TopPermission[];
}

export interface FailedAttempt {
  actor: string;
  actor_id: string;
  subject: string;
  subject_id: string;
  permission: string;
  attempt_count: number;
  last_attempt: string;
}

export interface FailedAttemptsResponse {
  attempts: FailedAttempt[];
}

export interface ServiceUsage {
  service_id: string;
  service_name: string;
  total_requests: number;
  avg_latency_ms: number;
  event_types_count: number;
}

export interface ServiceUsageResponse {
  services: ServiceUsage[];
}

export interface ApiKeyUsage {
  api_key_id: string;
  api_key_name: string;
  key_prefix: string;
  total_requests: number;
  last_used_at: string;
}

export interface ApiKeyUsageResponse {
  api_keys: ApiKeyUsage[];
}

export interface TimeSeriesDataPoint {
  timestamp: string;
  allowed: boolean;
  count: number;
}

export interface TimeSeriesResponse {
  data: TimeSeriesDataPoint[];
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
      const errorData = await response
        .json()
        .catch(() => ({ error: response.statusText }));

      // If there are validation errors, include them in the message
      if (errorData.errors && Array.isArray(errorData.errors) && errorData.errors.length > 0) {
        throw new Error(errorData.errors.join(', '));
      }

      throw new Error(
        errorData.error || errorData.message || `HTTP ${response.status}: ${response.statusText}`
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

  // Get schema information with statistics
  async getSchema(schemaName?: string): Promise<SchemaResponse> {
    const params = new URLSearchParams();
    if (schemaName) {
      params.append('schema_name', schemaName);
    }
    const queryString = params.toString();
    const url = `/api/schema${queryString ? `?${queryString}` : ''}`;

    const response = await fetch(`${this.baseUrl}${url}`, {
      headers: {
        "X-Service-Id": this.serviceId,
        "X-Tenant": this.tenant,
      },
    });

    if (!response.ok) {
      throw new Error(`Failed to fetch schema: ${response.statusText}`);
    }

    return response.json();
  }

  // Get relationship graph for visualization
  async getGraph(): Promise<GraphResponse> {
    const response = await fetch(`${this.baseUrl}/api/schema/graph`, {
      headers: {
        "X-Service-Id": this.serviceId,
        "X-Tenant": this.tenant,
      },
    });

    if (!response.ok) {
      throw new Error(`Failed to fetch graph: ${response.statusText}`);
    }

    return response.json();
  }

  // Get list of all entities
  async getEntities(): Promise<EntitiesResponse> {
    const response = await fetch(`${this.baseUrl}/api/schema/entities`, {
      headers: {
        "X-Service-Id": this.serviceId,
        "X-Tenant": this.tenant,
      },
    });

    if (!response.ok) {
      throw new Error(`Failed to fetch entities: ${response.statusText}`);
    }

    return response.json();
  }

  // Get relationships for a specific entity
  async getRelationships(entityId: string): Promise<GraphResponse> {
    // URL encode the entity_id since it contains ":"
    const encodedEntityId = encodeURIComponent(entityId);
    const response = await fetch(`${this.baseUrl}/api/schema/relationships/${encodedEntityId}`, {
      headers: {
        "X-Service-Id": this.serviceId,
        "X-Tenant": this.tenant,
      },
    });

    if (!response.ok) {
      throw new Error(`Failed to fetch relationships: ${response.statusText}`);
    }

    return response.json();
  }

  // Get all permissions for a specific actor
  async getActorPermissions(actorType: string, actorId: string): Promise<ActorPermissionsResponse> {
    const response = await fetch(
      `${this.baseUrl}/api/actors/${encodeURIComponent(actorType)}/${encodeURIComponent(actorId)}/permissions`,
      {
        headers: {
          "X-Service-Id": this.serviceId,
          "X-Tenant": this.tenant,
        },
      }
    );

    if (!response.ok) {
      throw new Error(`Failed to fetch actor permissions: ${response.statusText}`);
    }

    return response.json();
  }

  // Get all groups an actor is a member of
  async getActorGroups(actorType: string, actorId: string): Promise<ActorGroupsResponse> {
    const response = await fetch(
      `${this.baseUrl}/api/actors/${encodeURIComponent(actorType)}/${encodeURIComponent(actorId)}/groups`,
      {
        headers: {
          "X-Service-Id": this.serviceId,
          "X-Tenant": this.tenant,
        },
      }
    );

    if (!response.ok) {
      throw new Error(`Failed to fetch actor groups: ${response.statusText}`);
    }

    return response.json();
  }

  // Get all services
  async getServices(): Promise<ServicesResponse> {
    return this.request("GET", "/api/services");
  }

  // Get a specific service
  async getService(id: string): Promise<Service> {
    return this.request("GET", `/api/services/${id}`);
  }

  // Create a new service
  async createService(data: CreateServiceRequest): Promise<Service> {
    return this.request("POST", "/api/services", { service: data });
  }

  // Update a service
  async updateService(id: string, data: Partial<CreateServiceRequest>): Promise<Service> {
    return this.request("PATCH", `/api/services/${id}`, { service: data });
  }

  // Delete a service
  async deleteService(id: string): Promise<void> {
    return this.request("DELETE", `/api/services/${id}`);
  }

  // Regenerate service API key (deprecated - use createApiKey instead)
  async regenerateServiceKey(id: string): Promise<RegenerateKeyResponse> {
    return this.request("POST", `/api/services/${id}/regenerate_key`);
  }

  // Create a new API key for a service
  async createApiKey(serviceId: string, name?: string): Promise<{ message: string; api_key: string; service: Service }> {
    return this.request("POST", `/api/services/${serviceId}/api_keys`, { name });
  }

  // Revoke an API key
  async revokeApiKey(serviceId: string, apiKeyId: string): Promise<{ message: string; service: Service }> {
    return this.request("DELETE", `/api/services/${serviceId}/api_keys/${apiKeyId}`);
  }

  // Activate a service
  async activateService(id: string): Promise<Service> {
    return this.request("POST", `/api/services/${id}/activate`);
  }

  // Deactivate a service
  async deactivateService(id: string): Promise<Service> {
    return this.request("POST", `/api/services/${id}/deactivate`);
  }

  // Add allowed subject to service
  async addServiceSubject(id: string, subject: string): Promise<Service> {
    return this.request("POST", `/api/services/${id}/subjects`, { subject });
  }

  // Remove allowed subject from service
  async removeServiceSubject(id: string, subject: string): Promise<Service> {
    return this.request("DELETE", `/api/services/${id}/subjects/${encodeURIComponent(subject)}`);
  }

  // Add allowed relation to service
  async addServiceRelation(id: string, relation: string): Promise<Service> {
    return this.request("POST", `/api/services/${id}/relations`, { relation });
  }

  // Remove allowed relation from service
  async removeServiceRelation(id: string, relation: string): Promise<Service> {
    return this.request("DELETE", `/api/services/${id}/relations/${encodeURIComponent(relation)}`);
  }

  // Add schema to service
  async addServiceSchema(id: string, schema: string): Promise<Service> {
    return this.request("POST", `/api/services/${id}/schemas`, { schema });
  }

  // Remove schema from service
  async removeServiceSchema(id: string, schema: string): Promise<Service> {
    return this.request("DELETE", `/api/services/${id}/schemas/${encodeURIComponent(schema)}`);
  }

  // Analytics API

  // Get permission check metrics
  async getAnalyticsMetrics(params?: { since?: string; service_id?: string }): Promise<AnalyticsMetrics> {
    const queryParams = new URLSearchParams();
    if (params?.since) queryParams.append('since', params.since);
    if (params?.service_id) queryParams.append('service_id', params.service_id);
    const query = queryParams.toString();
    return this.request("GET", `/api/analytics/metrics${query ? `?${query}` : ''}`);
  }

  // Get top checked permissions
  async getTopPermissions(params?: { since?: string; limit?: number }): Promise<TopPermissionsResponse> {
    const queryParams = new URLSearchParams();
    if (params?.since) queryParams.append('since', params.since);
    if (params?.limit) queryParams.append('limit', params.limit.toString());
    const query = queryParams.toString();
    return this.request("GET", `/api/analytics/top_permissions${query ? `?${query}` : ''}`);
  }

  // Get failed access attempts
  async getFailedAttempts(params?: { since?: string; limit?: number }): Promise<FailedAttemptsResponse> {
    const queryParams = new URLSearchParams();
    if (params?.since) queryParams.append('since', params.since);
    if (params?.limit) queryParams.append('limit', params.limit.toString());
    const query = queryParams.toString();
    return this.request("GET", `/api/analytics/failed_attempts${query ? `?${query}` : ''}`);
  }

  // Get service usage statistics
  async getServiceUsage(params?: { since?: string }): Promise<ServiceUsageResponse> {
    const queryParams = new URLSearchParams();
    if (params?.since) queryParams.append('since', params.since);
    const query = queryParams.toString();
    return this.request("GET", `/api/analytics/service_usage${query ? `?${query}` : ''}`);
  }

  // Get API key usage statistics
  async getApiKeyUsage(params?: { since?: string; service_id?: string }): Promise<ApiKeyUsageResponse> {
    const queryParams = new URLSearchParams();
    if (params?.since) queryParams.append('since', params.since);
    if (params?.service_id) queryParams.append('service_id', params.service_id);
    const query = queryParams.toString();
    return this.request("GET", `/api/analytics/api_key_usage${query ? `?${query}` : ''}`);
  }

  // Get time-series data
  async getTimeSeries(params?: { since?: string; interval?: string }): Promise<TimeSeriesResponse> {
    const queryParams = new URLSearchParams();
    if (params?.since) queryParams.append('since', params.since);
    if (params?.interval) queryParams.append('interval', params.interval);
    const query = queryParams.toString();
    return this.request("GET", `/api/analytics/time_series${query ? `?${query}` : ''}`);
  }
}

// Default singleton instance
export const rebarClient = new RebarClient();
