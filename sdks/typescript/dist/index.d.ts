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
export declare class RebarClient {
    private baseUrl;
    private serviceId;
    private tenant;
    private timeout;
    constructor(config: RebarClientConfig);
    /**
     * Check if an actor has a specific permission on a subject
     */
    check(request: CheckRequest): Promise<boolean>;
    /**
     * Check permission and get explanation path
     */
    explain(request: CheckRequest): Promise<ExplainResponse>;
    /**
     * Create a relationship tuple
     */
    createTuple(tuple: RelTuple): Promise<void>;
    /**
     * Delete a relationship tuple
     */
    deleteTuple(tuple: RelTuple): Promise<void>;
    /**
     * Batch create relationship tuples
     */
    batchCreateTuples(tuples: RelTuple[]): Promise<void>;
    /**
     * Get all permissions for an actor
     */
    getActorPermissions(actorType: string, actorId: string): Promise<ActorPermissionsResponse>;
    /**
     * Get all groups an actor is a member of
     */
    getActorGroups(actorType: string, actorId: string): Promise<ActorGroupsResponse>;
    /**
     * Get audit logs
     */
    getAuditLogs(params?: {
        page?: number;
        perPage?: number;
        subject?: string;
        actor?: string;
        action?: string;
    }): Promise<AuditLogsResponse>;
    /**
     * Get schema information
     */
    getSchema(): Promise<any>;
    /**
     * Change tenant for subsequent requests
     */
    setTenant(tenant: string): void;
    /**
     * Internal request method
     */
    private request;
}
export declare function useRebarClient(config: RebarClientConfig): RebarClient;
