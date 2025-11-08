"use strict";
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
Object.defineProperty(exports, "__esModule", { value: true });
exports.RebarClient = void 0;
exports.useRebarClient = useRebarClient;
class RebarClient {
    constructor(config) {
        this.baseUrl = config.baseUrl.replace(/\/$/, '');
        this.serviceId = config.serviceId;
        this.tenant = config.tenant || 'default';
        this.timeout = config.timeout || 10000;
    }
    /**
     * Check if an actor has a specific permission on a subject
     */
    async check(request) {
        const response = await this.request('/api/auth/check', {
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
    async explain(request) {
        return this.request('/api/auth/explain', {
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
    async createTuple(tuple) {
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
    async deleteTuple(tuple) {
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
    async batchCreateTuples(tuples) {
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
    async getActorPermissions(actorType, actorId) {
        return this.request(`/api/actors/${actorType}/${actorId}/permissions`);
    }
    /**
     * Get all groups an actor is a member of
     */
    async getActorGroups(actorType, actorId) {
        return this.request(`/api/actors/${actorType}/${actorId}/groups`);
    }
    /**
     * Get audit logs
     */
    async getAuditLogs(params) {
        const query = new URLSearchParams();
        if (params?.page)
            query.set('page', params.page.toString());
        if (params?.perPage)
            query.set('per_page', params.perPage.toString());
        if (params?.subject)
            query.set('subject', params.subject);
        if (params?.actor)
            query.set('actor', params.actor);
        if (params?.action)
            query.set('action', params.action);
        const url = `/api/audit_logs${query.toString() ? '?' + query.toString() : ''}`;
        return this.request(url);
    }
    /**
     * Get schema information
     */
    async getSchema() {
        return this.request('/api/schema');
    }
    /**
     * Change tenant for subsequent requests
     */
    setTenant(tenant) {
        this.tenant = tenant;
    }
    /**
     * Internal request method
     */
    async request(path, init) {
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
            const error = await response.json().catch(() => ({ error: response.statusText }));
            throw new Error(`Rebar API error: ${error.error || error.message || response.statusText}`);
        }
        return response.json();
    }
}
exports.RebarClient = RebarClient;
// React hook for easy integration
function useRebarClient(config) {
    const client = new RebarClient(config);
    return client;
}
