# Rebar - Relationship-Based Access Control (ReBAC) Service

Rebar is a flexible authorization service implementing Relationship-Based Access Control (ReBAC) with support for hierarchical permissions, group-based access, and computed permissions.

## Features

- 🔐 **Relationship-Based Authorization** - Define permissions through entity relationships
- 👥 **Group Permissions** - Grant access through group memberships with role-based filtering
- 🌳 **Hierarchical Permissions** - Inherit permissions from parent entities (folders, organizations)
- ⚡ **Computed Permissions** - Custom permission logic with Ruby DSL
- 🔍 **Permission Explanation** - Trace why a permission is granted
- 📊 **Audit Logging** - Complete audit trail of all authorization changes
- 🎨 **React UI** - Visual interface for managing tuples, viewing permissions, and exploring relationships
- 🚀 **Fast BFS Traversal** - Efficient graph traversal with depth limiting

## Quick Start

### Prerequisites

- Docker and Docker Compose
- (Optional) Ruby 3.3+ for local development
- (Optional) Node.js 18+ for frontend development

### Running with Docker

```bash
# Start all services (Rails API, PostgreSQL, React frontend)
docker compose up

# Run database migrations
docker compose exec api rails db:migrate

# Load sample data (optional)
docker compose exec api rails db:seed
```

Services:
- **API**: http://localhost:3000
- **Frontend**: http://localhost:8080
- **PostgreSQL**: localhost:5432

## API Documentation

Comprehensive API documentation is integrated into the UI:

- **Integrated Docs** (recommended): http://localhost:8080/docs
  - Quick start guide with common examples
  - Styled with the main application UI
  - Easy to navigate with tabs

- **OpenAPI/Swagger**: http://localhost:3000/api/openapi/index.html
  - Interactive API explorer
  - Complete endpoint reference
  - OpenAPI spec: http://localhost:3000/api/openapi/v1/swagger.yaml

To regenerate OpenAPI documentation after API changes:
```bash
bin/generate_docs
```

## Authorization Schema

The authorization schema is defined in `config/auth_schema.rb` using a Ruby DSL:

```ruby
AuthSchema.define do
  # Define entity types
  type :user

  type :group do
    relation :member, allow: [:user, :group]
  end

  type :doc do
    relation :parent, allow: [:folder]
    relation :owner, allow: [:user, :group]
    relation :editor, allow: [:owner, "parent->editor"]
    relation :viewer, allow: [:editor, "parent->viewer"]

    # Computed permissions
    permission :can_view do |context|
      context.check(context.actor, context.actor_id, :viewer, context.subject, context.subject_id)
    end

    permission :can_edit do |context|
      context.check(context.actor, context.actor_id, :editor, context.subject, context.subject_id)
    end

    permission :can_delete do |context|
      # Only direct owner can delete
      context.check(context.actor, context.actor_id, :owner, context.subject, context.subject_id)
    end
  end

  type :folder do
    relation :owner, allow: [:user, :group, "parent->owner"]
    relation :editor, allow: [:owner, "parent->editor"]
    relation :viewer, allow: [:editor, "parent->viewer"]
  end
end
```

### Schema Patterns

- **Union**: `allow: [:owner, :editor]` - Permission granted if actor has ANY of these relations
- **Parent Inheritance**: `"parent->editor"` - Permission granted if actor has `editor` relation to parent entity
- **Group Roles**: `"group#member"` - Permission granted to group members with specific role
- **Computed Permissions**: Custom Ruby code evaluated at runtime

## API Endpoints

### Authorization

#### Check Permission

**JSON Format:**
```bash
POST /api/auth/check
Headers: X-Service-Id, X-Tenant
Body: {
  "actor": "user",
  "actor_id": "alice",
  "permission": "viewer",
  "subject": "doc",
  "subject_id": "quarterly-report"
}
Response: { "allow": true }
```

**Zanzibar Tuple Format:**
```bash
POST /api/auth/check
Headers: X-Service-Id, X-Tenant
Body: {
  "tuple": "doc:quarterly-report#viewer@user:alice"
}
Response: { "allow": true }
```

The tuple format follows the standard Zanzibar notation: `subject:id#relation@actor:id`

#### Explain Permission
```bash
POST /api/auth/explain
Headers: X-Service-Id, X-Tenant
Body: {
  "actor": "user",
  "actor_id": "alice",
  "permission": "viewer",
  "subject": "doc",
  "subject_id": "quarterly-report"
}
Response: {
  "allow": true,
  "path": [
    ["union", "viewer", "editor"],
    ["union", "editor", "owner"],
    {"kind": "direct", "relation": "owner", ...}
  ]
}
```

### Relationship Tuples

#### Create Relationship
```bash
POST /api/tuples
Headers: X-Service-Id, X-Tenant
Body: {
  "subject": "doc",
  "id": "quarterly-report",
  "relation": "owner",
  "actor": "user",
  "actor_id": "alice"
}
Response: { "ok": true }
```

#### Batch Create
```bash
POST /api/tuples/batch
Headers: X-Service-Id, X-Tenant
Body: {
  "tuples": [
    {
      "subject": "group",
      "id": "engineering",
      "relation": "member",
      "actor": "user",
      "actor_id": "bob"
    },
    {
      "subject": "doc",
      "id": "tech-specs",
      "relation": "viewer",
      "actor": "group",
      "actor_id": "engineering",
      "actor_rel": "member"
    }
  ]
}
Response: { "ok": true, "count": 2 }
```

#### Delete Relationship
```bash
DELETE /api/tuples
Headers: X-Service-Id, X-Tenant
Body: {
  "subject": "doc",
  "id": "quarterly-report",
  "relation": "editor",
  "actor": "user",
  "actor_id": "bob"
}
Response: { "ok": true }
```

### Actor Permissions

#### Get All Permissions for an Actor
```bash
GET /api/actors/user/alice/permissions
Headers: X-Service-Id, X-Tenant
Response: {
  "actor": "user:alice",
  "total_permissions": 3,
  "direct_count": 1,
  "group_count": 1,
  "inherited_count": 1,
  "group_memberships": ["group:engineering"],
  "resources": [
    {
      "resource": "doc:quarterly-report",
      "resource_type": "doc",
      "resource_id": "quarterly-report",
      "permissions": [
        {
          "permission": "owner",
          "type": "direct",
          "via": null
        }
      ],
      "actions": ["can_view", "can_edit", "can_delete", "can_archive"]
    }
  ]
}
```

This endpoint returns:
- **Direct permissions**: Explicitly granted to the actor
- **Group permissions**: Granted through group membership
- **Inherited permissions**: Granted through parent relationships or cascading permissions
- **Actions**: Computed permissions the actor can perform

### Schema and Discovery

#### Get Schema
```bash
GET /api/schema
Headers: X-Service-Id, X-Tenant
Response: {
  "types": { ... },
  "stats": {
    "doc": {
      "as_subject": 5,
      "as_actor": 0,
      "total": 5,
      "relations": ["owner", "editor", "viewer"]
    }
  }
}
```

#### Get Relationship Graph
```bash
GET /api/schema/graph
Headers: X-Service-Id, X-Tenant
Response: {
  "nodes": [...],
  "edges": [...],
  "node_count": 10,
  "edge_count": 15
}
```

#### Get Entity Relationships
```bash
GET /api/schema/relationships/user:alice
Headers: X-Service-Id, X-Tenant
Response: {
  "nodes": [...],
  "edges": [...],
  "center_entity": "user:alice"
}
```

### Audit Logs

#### Get Audit Logs
```bash
GET /api/audit_logs?action_type=create&subject=doc&page=1&per_page=20
Headers: X-Service-Id, X-Tenant
Response: {
  "logs": [...],
  "page": 1,
  "per_page": 20
}
```

#### Get Audit Statistics
```bash
GET /api/audit_logs/stats?since=2024-01-01
Headers: X-Service-Id, X-Tenant
Response: {
  "total_count": 150,
  "by_action": { "create": 100, "delete": 50 },
  "by_service": { "dev": 150 },
  "by_resource_type": { "doc": 80, "group": 70 }
}
```

## Permission Types

### 1. Direct Permissions

Created when you explicitly grant a relationship:

```ruby
# Alice owns quarterly-report
{ subject: "doc", id: "quarterly-report", relation: "owner", actor: "user", actor_id: "alice" }
```

Result: Alice has `owner` permission (direct)

### 2. Group Permissions

Granted through group membership:

```ruby
# Bob is member of engineering group
{ subject: "group", id: "engineering", relation: "member", actor: "user", actor_id: "bob" }

# Engineering group has viewer access to tech-specs
{ subject: "doc", id: "tech-specs", relation: "viewer", actor: "group", actor_id: "engineering", actor_rel: "member" }
```

Result: Bob has `viewer` permission on tech-specs (via group:engineering#member)

### 3. Inherited Permissions

Automatically resolved through schema-defined relationships:

```ruby
# Bob owns reports folder
{ subject: "folder", id: "reports", relation: "owner", actor: "user", actor_id: "bob" }

# budget-2024 is in reports folder
{ subject: "doc", id: "budget-2024", relation: "parent", actor: "folder", actor_id: "reports" }
```

Result: Bob has `viewer`, `editor` permissions on budget-2024 (inherited via parent folder ownership)

**Permission Chain**:
1. Bob is `owner` of `folder:reports` (direct)
2. Schema: `owner` satisfies `editor`
3. Schema: Document's `editor` allows `"parent->editor"`
4. Schema: `editor` satisfies `viewer`
5. **Result**: Bob can view, edit, and archive budget-2024

## Frontend Integration

### TypeScript Client

```typescript
import { rebarClient } from './api/rebar';

// Check permission before showing UI
const canEdit = await rebarClient.checkPermission({
  actor: 'user',
  actor_id: currentUserId,
  permission: 'can_edit',
  subject: 'doc',
  subject_id: documentId
});

if (canEdit) {
  // Show edit button
}

// Get all permissions for current user
const permissions = await rebarClient.getActorPermissions('user', currentUserId);

// Filter resources by type
const documents = permissions.resources.filter(r => r.resource_type === 'doc');

// Check available actions
documents.forEach(doc => {
  console.log(`Actions for ${doc.resource}:`, doc.actions);
  // actions: ["can_view", "can_edit", "can_delete"]
});
```

### React Component Example

```typescript
function DocumentList({ userId }: { userId: string }) {
  const [permissions, setPermissions] = useState<ActorPermissionsResponse | null>(null);

  useEffect(() => {
    rebarClient.getActorPermissions('user', userId)
      .then(setPermissions);
  }, [userId]);

  const documents = permissions?.resources.filter(r => r.resource_type === 'doc') || [];

  return (
    <div>
      {documents.map(doc => (
        <div key={doc.resource}>
          <h3>{doc.resource_id}</h3>
          {doc.actions.includes('can_edit') && (
            <button>Edit</button>
          )}
          {doc.actions.includes('can_delete') && (
            <button>Delete</button>
          )}
        </div>
      ))}
    </div>
  );
}
```

### Backend Enforcement

**Always enforce permissions on the backend**, even if the frontend hides UI elements:

```ruby
class DocumentsController < ApplicationController
  def update
    @document = Document.find(params[:id])

    # Enforce permission check
    engine = PermissionEngine.new(
      schema_path: Rails.root.join("config/auth_schema.rb"),
      repo: RebacRepo.new(tenant_id: current_tenant)
    )

    unless engine.check(current_user.type, current_user.id, :can_edit, 'doc', @document.external_id)
      render json: { error: 'Permission denied' }, status: :forbidden
      return
    end

    # Update document...
  end
end
```

## Example Scenarios

### Example 1: Document Ownership with Parent Inheritance

```bash
# Create folder owned by Bob
POST /api/tuples
{
  "subject": "folder",
  "id": "reports",
  "relation": "owner",
  "actor": "user",
  "actor_id": "bob"
}

# Create document with parent folder
POST /api/tuples
{
  "subject": "doc",
  "id": "budget-2024",
  "relation": "parent",
  "actor": "folder",
  "actor_id": "reports"
}

# Check Bob's permissions
GET /api/actors/user/bob/permissions

# Result:
# - folder:reports → owner (direct) → [can_delete, can_move, can_share]
# - doc:budget-2024 → viewer (inherited via parent) → [can_view, can_edit, can_archive]
```

### Example 2: Group-Based Access

```bash
# Create group with members
POST /api/tuples/batch
{
  "tuples": [
    {
      "subject": "group",
      "id": "engineering",
      "relation": "member",
      "actor": "user",
      "actor_id": "alice"
    },
    {
      "subject": "group",
      "id": "engineering",
      "relation": "member",
      "actor": "user",
      "actor_id": "bob"
    },
    {
      "subject": "doc",
      "id": "tech-specs",
      "relation": "viewer",
      "actor": "group",
      "actor_id": "engineering",
      "actor_rel": "member"
    }
  ]
}

# Check Alice's permissions
GET /api/actors/user/alice/permissions

# Result:
# - group:engineering → member (direct) → []
# - doc:tech-specs → viewer (via group:engineering#member) → [can_view]
```

### Example 3: Permission Cascading

```bash
# Alice owns a document
POST /api/tuples
{
  "subject": "doc",
  "id": "quarterly-report",
  "relation": "owner",
  "actor": "user",
  "actor_id": "alice"
}

# Schema defines: editor allows [owner]
# Schema defines: viewer allows [editor]
# Result: Alice has owner, editor, and viewer permissions

GET /api/actors/user/alice/permissions
# alice can: view, edit, delete, archive quarterly-report
```

## Multi-Tenancy

Rebar supports multi-tenancy through the `X-Tenant` header:

```bash
# Development tenant
curl -H "X-Tenant: development" -H "X-Service-Id: app1" ...

# Production tenant
curl -H "X-Tenant: production" -H "X-Service-Id: app1" ...
```

All data is isolated by tenant. Each tenant has:
- Separate relationship tuples
- Separate audit logs
- Shared authorization schema

## Development

### Running Tests

```bash
docker compose exec api rspec
```

### Database Management

```bash
# Create database
docker compose exec api rails db:create

# Run migrations
docker compose exec api rails db:migrate

# Rollback migration
docker compose exec api rails db:rollback

# Reset database
docker compose exec api rails db:reset
```

### Schema Changes

Edit `config/auth_schema.rb` and restart the API:

```bash
docker compose restart api
```

### Frontend Development

```bash
cd web
npm install
npm run dev
```

## Architecture

### Components

1. **Rails API** (`app/`)
   - `controllers/api/` - REST API endpoints
   - `services/` - Business logic (PermissionEngine, RebacRepo)
   - `models/` - ActiveRecord models

2. **Authorization Schema** (`config/auth_schema.rb`)
   - DSL for defining entity types and relations
   - Computed permission definitions

3. **Permission Engine** (`app/services/permission_engine.rb`)
   - BFS graph traversal
   - Permission explanation
   - Computed permission evaluation

4. **React Frontend** (`web/src/`)
   - Tuple management
   - Permission explorer
   - Relationship visualization
   - Audit log viewer

### Database Schema

```sql
CREATE TABLE rel_tuples (
  pk SERIAL PRIMARY KEY,
  tenant_id VARCHAR NOT NULL,
  subject VARCHAR NOT NULL,
  id VARCHAR NOT NULL,
  relation VARCHAR NOT NULL,
  actor VARCHAR NOT NULL,
  actor_id VARCHAR NOT NULL,
  actor_rel VARCHAR,
  created_at TIMESTAMP,
  updated_at TIMESTAMP,
  UNIQUE (tenant_id, subject, id, relation, actor, actor_id, COALESCE(actor_rel, ''))
);

CREATE TABLE audit_logs (
  id SERIAL PRIMARY KEY,
  tenant_id VARCHAR NOT NULL,
  service_id VARCHAR NOT NULL,
  actor_user_id VARCHAR,
  ip_address VARCHAR,
  action VARCHAR NOT NULL,
  resource_type VARCHAR NOT NULL,
  tuple JSONB,
  before_state JSONB,
  after_state JSONB,
  reason VARCHAR,
  metadata JSONB,
  created_at TIMESTAMP
);
```

## Load Testing & Performance Benchmarking

Rebar includes a data generation tool for testing at scale.

### Generate Large-Scale Test Data

Generate 1 million actors with 10+ relationships each:

```bash
# Generate 1M actors, 20 entity types, 10M+ relationships
docker compose exec api rails data:generate_large

# Or customize the scale
docker compose exec api rails data:generate_large ACTORS=100000 RELATIONSHIPS=15 TENANT=load-test

# View statistics
docker compose exec api rails data:stats TENANT=load-test

# Clean up test data
docker compose exec api rails data:clean_large TENANT=load-test
```

### Test Data Specifications

The generator creates:
- **1,000,000 unique user actors** (user-0 through user-999999)
- **100,000 groups** (10 users per group)
- **20 entity types**:
  - 500K documents, 100K folders, 50K projects
  - 100K repositories, 300K issues, 200K pull requests
  - Departments, teams, workspaces, pipelines, secrets, etc.
- **10+ relationships per actor** (10M+ total tuples)
- **Hierarchical relationships**: org → dept → team, workspace → project → folder → document
- **Group-based permissions**: 20% of permissions granted through groups
- **Diverse relationships**: owner, admin, editor, viewer, member, contributor, reviewer, maintainer

### Performance Benchmarks

Expected performance on standard hardware (4 CPU, 8GB RAM):

**Data Generation**:
- ~5,000-10,000 tuples/second
- 1M actors + 10M relationships: ~20-30 minutes

**Permission Checks**:
- Direct permissions: < 5ms
- Group permissions: < 10ms
- Inherited permissions (2-3 levels): < 20ms
- Complex hierarchies (5+ levels): < 50ms

**Actor Permissions Endpoint**:
- Actors with < 10 resources: < 100ms
- Actors with 10-50 resources: < 500ms
- Actors with 50+ resources: < 1s

### Testing Examples

After generating data:

```bash
# Test random user permissions
curl -H "X-Tenant: load-test" http://localhost:3000/api/actors/user/user-12345/permissions

# Check specific permission
curl -X POST http://localhost:3000/api/auth/check \
  -H "X-Tenant: load-test" \
  -H "Content-Type: application/json" \
  -d '{
    "actor": "user",
    "actor_id": "user-50000",
    "permission": "viewer",
    "subject": "document",
    "subject_id": "doc-12345"
  }'

# Get statistics
curl -H "X-Tenant: load-test" http://localhost:3000/api/schema
```

### Database Optimization

For large datasets, ensure proper indexes:

```sql
-- Core indexes (should exist by default)
CREATE INDEX idx_tuples_tenant_subject_id ON rel_tuples(tenant_id, subject, id);
CREATE INDEX idx_tuples_tenant_actor ON rel_tuples(tenant_id, actor, actor_id);
CREATE INDEX idx_tuples_tenant_relation ON rel_tuples(tenant_id, relation);

-- Additional indexes for performance
CREATE INDEX idx_tuples_subject_id ON rel_tuples(subject, id);
CREATE INDEX idx_tuples_actor_actor_id ON rel_tuples(actor, actor_id);
```

### Scaling Considerations

For production deployments with millions of actors:

1. **PostgreSQL Tuning**:
   - Increase `shared_buffers` (25% of RAM)
   - Increase `effective_cache_size` (50-75% of RAM)
   - Tune `work_mem` for sorting/joining
   - Enable `pg_stat_statements` for query analysis

2. **Connection Pooling**:
   - Use PgBouncer or similar
   - Limit concurrent connections
   - Monitor connection pool utilization

3. **Caching Strategy**:
   - Cache frequently-checked permissions (Redis)
   - Cache actor permissions for active users
   - Set appropriate TTL based on tuple change frequency

4. **Read Replicas**:
   - Route read-only queries to replicas
   - Use primary only for writes
   - Monitor replication lag

5. **Sharding** (for extreme scale):
   - Shard by tenant_id
   - Co-locate related data
   - Use connection pooling per shard

## Performance Considerations

- **Depth Limiting**: BFS traversal limited to 6 levels (configurable in `PermissionEngine::MAX_DEPTH`)
- **Caching**: Consider caching permission checks in production (Redis with 5-15min TTL)
- **Indexes**: Database indexes on (tenant_id, subject, id, relation) and (tenant_id, actor, actor_id)
- **Batch Operations**: Use batch endpoints for bulk tuple creation/deletion (10,000 tuples/batch recommended)
- **Query Optimization**: Monitor slow queries with `pg_stat_statements` and add indexes as needed

## Security Best Practices

1. **Always validate on backend**: Never trust frontend permission checks
2. **Use service authentication**: Implement `ServiceAuth` concern on controllers
3. **Audit everything**: All tuple changes are automatically logged
4. **Principle of least privilege**: Grant minimal necessary permissions
5. **Regular audits**: Review audit logs for suspicious activity

## Contributing

1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Submit a pull request

## License

[Your License Here]

## Support

For questions and support, please [open an issue](https://github.com/yourorg/rebar/issues).
