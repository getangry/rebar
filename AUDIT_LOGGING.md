# Audit Logging

Rebar includes comprehensive audit logging for all relationship tuple operations. Every create, update, and delete operation is automatically logged with the **who, what, where, when, and why** details.

## Overview

Audit logs capture:
- **Who**: Service ID, optional user ID, IP address, and user agent
- **What**: The action (create/delete/update) and the complete tuple data
- **Where**: IP address and user agent of the client
- **When**: Timestamp of the operation
- **Why**: Optional reason field for documenting the purpose

## Automatic Logging

All tuple operations are automatically logged:
- Creating a relationship tuple
- Deleting a relationship tuple
- Batch operations (tracked with operation count)

Logs are only created when operations actually succeed. Duplicate inserts (conflicts) and failed operations are not logged.

## Audit Log Schema

```ruby
{
  id: integer,                    # Unique log ID
  tenant_id: string,              # Multi-tenant isolation
  service_id: string,             # Service that performed the action
  actor_user_id: string,          # Optional: actual user ID
  ip_address: string,             # Client IP address
  user_agent: string,             # Client user agent
  action: string,                 # "create", "delete", "update"
  resource_type: string,          # "rel_tuple" (extensible)

  # The tuple data
  subject: string,
  object_id: string,
  relation: string,
  actor: string,
  actor_id: string,
  actor_rel: string,

  # State tracking
  before_state: json,             # State before operation (for deletes/updates)
  after_state: json,              # State after operation (for creates/updates)

  # Context
  reason: string,                 # Optional explanation
  metadata: json,                 # Additional context

  created_at: timestamp           # When the operation occurred
}
```

## API Endpoints

### Query Audit Logs

**GET /api/audit_logs**

Get a paginated list of audit logs with optional filters.

**Query Parameters:**
- `service_id` - Filter by service
- `action` - Filter by action (create/delete/update)
- `subject` + `object_id` - Filter by resource
- `actor` + `actor_id` - Filter by actor
- `since` - Filter by timestamp (ISO 8601)
- `page` - Page number (default: 1)
- `per_page` - Results per page (default: 50, max: 1000)

**Example:**
```bash
curl -X GET "http://localhost:3000/api/audit_logs?action=create&page=1&per_page=20" \
  -H "X-Service-Id: dev" \
  -H "X-Tenant: acme-corp"
```

**Response:**
```json
{
  "logs": [
    {
      "id": 123,
      "tenant_id": "acme-corp",
      "service_id": "dev",
      "ip_address": "192.168.1.100",
      "user_agent": "curl/7.64.1",
      "action": "create",
      "resource_type": "rel_tuple",
      "tuple": {
        "subject": "doc",
        "object_id": "report-1",
        "relation": "owner",
        "actor": "user",
        "actor_id": "alice"
      },
      "after_state": { ... },
      "reason": "Initial setup",
      "created_at": "2024-01-15T10:30:00Z",
      "summary": "CREATE doc:report-1 owner by user:alice (reason: Initial setup)"
    }
  ],
  "page": 1,
  "per_page": 20
}
```

---

### Get Specific Log

**GET /api/audit_logs/:id**

Retrieve a single audit log entry.

**Example:**
```bash
curl -X GET "http://localhost:3000/api/audit_logs/123" \
  -H "X-Service-Id: dev" \
  -H "X-Tenant: acme-corp"
```

---

### Get Tuple History

**GET /api/audit_logs/tuple_history**

Get the complete audit history for a specific relationship tuple.

**Query Parameters (all required):**
- `subject` - Subject namespace
- `object_id` - Object ID
- `relation` - Relation type
- `actor` - Actor namespace
- `actor_id` - Actor ID

**Example:**
```bash
curl -X GET "http://localhost:3000/api/audit_logs/tuple_history?subject=doc&object_id=report-1&relation=owner&actor=user&actor_id=alice" \
  -H "X-Service-Id: dev" \
  -H "X-Tenant: acme-corp"
```

**Response:**
```json
{
  "tuple": {
    "subject": "doc",
    "object_id": "report-1",
    "relation": "owner",
    "actor": "user",
    "actor_id": "alice"
  },
  "history": [
    {
      "action": "delete",
      "reason": "Access revoked",
      "created_at": "2024-01-15T14:00:00Z"
    },
    {
      "action": "create",
      "reason": "Initial setup",
      "created_at": "2024-01-15T10:00:00Z"
    }
  ]
}
```

---

### Get Statistics

**GET /api/audit_logs/stats**

Get aggregated statistics about audit logs.

**Query Parameters:**
- `since` - Only include logs after this timestamp (ISO 8601)

**Example:**
```bash
curl -X GET "http://localhost:3000/api/audit_logs/stats?since=2024-01-01T00:00:00Z" \
  -H "X-Service-Id: dev" \
  -H "X-Tenant: acme-corp"
```

**Response:**
```json
{
  "total_count": 1523,
  "by_action": {
    "create": 892,
    "delete": 631
  },
  "by_service": {
    "api-service": 1200,
    "admin-tool": 323
  },
  "by_resource_type": {
    "rel_tuple": 1523
  }
}
```

---

## Adding Reasons to Operations

You can include a `reason` field in any tuple operation to document why the change was made:

```bash
# Create with reason
curl -X POST http://localhost:3000/api/tuples \
  -H "Content-Type: application/json" \
  -H "X-Service-Id: dev" \
  -H "X-Tenant: default" \
  -d '{
    "subject": "doc",
    "id": "report-1",
    "relation": "owner",
    "actor": "user",
    "actor_id": "alice",
    "reason": "Document created by Alice for Q4 reporting"
  }'

# Delete with reason
curl -X DELETE http://localhost:3000/api/tuples \
  -H "Content-Type: application/json" \
  -H "X-Service-Id: dev" \
  -H "X-Tenant: default" \
  -d '{
    "subject": "doc",
    "id": "report-1",
    "relation": "owner",
    "actor": "user",
    "actor_id": "alice",
    "reason": "User left organization"
  }'
```

## Use Cases

### 1. Compliance & Auditing

Track who made what changes for compliance requirements (SOC 2, HIPAA, GDPR):

```bash
# Get all access grants in the last 30 days
curl -X GET "http://localhost:3000/api/audit_logs?action=create&since=2024-01-01T00:00:00Z" \
  -H "X-Service-Id: dev" \
  -H "X-Tenant: acme-corp"
```

### 2. Security Investigations

Investigate suspicious activity or security incidents:

```bash
# Get all actions by a specific service
curl -X GET "http://localhost:3000/api/audit_logs?service_id=suspicious-service" \
  -H "X-Service-Id: admin" \
  -H "X-Tenant: acme-corp"

# Check what a specific user has accessed
curl -X GET "http://localhost:3000/api/audit_logs?actor=user&actor_id=suspicious-user" \
  -H "X-Service-Id: admin" \
  -H "X-Tenant: acme-corp"
```

### 3. Debugging Permission Issues

Understand when and why a permission was granted or revoked:

```bash
# Get full history of a specific relationship
curl -X GET "http://localhost:3000/api/audit_logs/tuple_history?subject=doc&object_id=report-1&relation=owner&actor=user&actor_id=alice" \
  -H "X-Service-Id: dev" \
  -H "X-Tenant: acme-corp"
```

### 4. Usage Analytics

Understand patterns of permission grants and revocations:

```bash
# Get statistics for the current month
curl -X GET "http://localhost:3000/api/audit_logs/stats?since=2024-01-01T00:00:00Z" \
  -H "X-Service-Id: dev" \
  -H "X-Tenant: acme-corp"
```

## Data Retention

Audit logs are stored indefinitely by default. You should implement a retention policy based on your compliance requirements:

```ruby
# Example: Delete logs older than 90 days
AuditLog.where("created_at < ?", 90.days.ago).delete_all
```

## Performance Considerations

1. **Indexes**: The audit_logs table has indexes optimized for common queries (tenant+time, tenant+service, tenant+resource, tenant+actor)

2. **Non-blocking**: Audit logging failures don't block operations - they're logged to Rails.logger instead

3. **Pagination**: Always use pagination when querying large date ranges

4. **Archival**: Consider archiving old logs to a data warehouse for long-term storage and analytics

## Security Notes

1. **Access Control**: The audit logs endpoint requires service authentication. In production, implement additional access controls to restrict who can view audit logs.

2. **Sensitive Data**: Be cautious about logging sensitive data in the `reason` or `metadata` fields.

3. **Multi-tenancy**: Audit logs are isolated by tenant_id to ensure data privacy.

4. **IP Tracking**: IP addresses are logged for security investigations, but be aware of privacy regulations (GDPR, CCPA).

## Example: Building an Audit Trail UI

```ruby
# In your admin dashboard
class AuditTrailController < ApplicationController
  def index
    @logs = AuditLog
      .for_tenant(current_tenant)
      .recent
      .page(params[:page])
      .per(50)

    # Apply filters
    @logs = @logs.for_service(params[:service]) if params[:service].present?
    @logs = @logs.for_action(params[:action]) if params[:action].present?
    @logs = @logs.since(Time.parse(params[:since])) if params[:since].present?
  end

  def show
    @log = AuditLog.for_tenant(current_tenant).find(params[:id])
    @related = AuditLog.tuple_history(
      tenant_id: current_tenant,
      subject: @log.subject,
      object_id: @log.object_id,
      relation: @log.relation,
      actor: @log.actor,
      actor_id: @log.actor_id
    )
  end
end
```

## Schema Migration

To add audit logging to an existing Rebar installation:

```bash
# Run the migration
rails db:migrate

# Verify the table was created
rails dbconsole
\d audit_logs
```
