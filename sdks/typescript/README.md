# @rebar/sdk - TypeScript SDK

Official TypeScript/JavaScript SDK for Rebar ReBAC authorization service.

## Installation

```bash
npm install @rebar/sdk
```

## Usage

### Basic Setup

```typescript
import { RebarClient } from '@rebar/sdk';

const client = new RebarClient({
  baseUrl: 'http://localhost:3000',
  serviceId: 'my-app',
  tenant: 'default'
});
```

### Check Permissions

```typescript
// Check if user can edit a document
const canEdit = await client.check({
  actor: 'user',
  actorId: 'alice',
  permission: 'can_edit',
  subject: 'doc',
  subjectId: 'doc-123'
});

if (canEdit) {
  console.log('Alice can edit doc-123');
}
```

### Get Explanation

```typescript
// Get why permission is granted
const result = await client.explain({
  actor: 'user',
  actorId: 'alice',
  permission: 'viewer',
  subject: 'document',
  subjectId: 'doc-123'
});

console.log('Allowed:', result.allow);
console.log('Path:', result.path);
```

### Manage Relationships

```typescript
// Grant permission
await client.createTuple({
  subject: 'doc',
  id: 'doc-123',
  relation: 'editor',
  actor: 'user',
  actorId: 'alice'
});

// Revoke permission
await client.deleteTuple({
  subject: 'doc',
  id: 'doc-123',
  relation: 'editor',
  actor: 'user',
  actorId: 'alice'
});

// Batch create
await client.batchCreateTuples([
  { subject: 'doc', id: 'doc-1', relation: 'viewer', actor: 'user', actorId: 'alice' },
  { subject: 'doc', id: 'doc-2', relation: 'editor', actor: 'user', actorId: 'bob' }
]);
```

### Get Actor Permissions

```typescript
// Get all permissions for a user
const permissions = await client.getActorPermissions('user', 'alice');

console.log(`Total permissions: ${permissions.totalPermissions}`);
console.log(`Direct: ${permissions.directCount}`);
console.log(`Group: ${permissions.groupCount}`);
console.log(`Inherited: ${permissions.inheritedCount}`);

permissions.resources.forEach(resource => {
  console.log(`\n${resource.resource}:`);
  console.log('  Permissions:', resource.permissions.map(p => p.permission));
  console.log('  Actions:', resource.actions);
});
```

### Get Group Memberships

```typescript
const groups = await client.getActorGroups('user', 'alice');

groups.memberships.forEach(membership => {
  console.log(`${membership.group} as ${membership.role}`);
});
```

### Audit Logs

```typescript
const logs = await client.getAuditLogs({
  page: 1,
  perPage: 50,
  subject: 'doc:123',
  action: 'create'
});

logs.logs.forEach(log => {
  console.log(`${log.action}: ${log.subject}:${log.subjectId} by ${log.performedBy}`);
});
```

### React Integration

```typescript
import { useRebarClient } from '@rebar/sdk';
import { useState, useEffect } from 'react';

function DocumentEditor({ docId }) {
  const client = useRebarClient({
    baseUrl: process.env.REBAR_URL,
    serviceId: 'my-app',
    tenant: 'default'
  });

  const [canEdit, setCanEdit] = useState(false);

  useEffect(() => {
    client.check({
      actor: 'user',
      actorId: getCurrentUserId(),
      permission: 'can_edit',
      subject: 'doc',
      subjectId: docId
    }).then(setCanEdit);
  }, [docId]);

  if (!canEdit) {
    return <div>You don't have permission to edit this document</div>;
  }

  return <DocumentEditForm docId={docId} />;
}
```

### Multi-Tenant Support

```typescript
// Change tenant dynamically
client.setTenant('tenant-123');

// All subsequent requests use the new tenant
const allowed = await client.check({...});
```

## API Reference

### `RebarClient`

#### Constructor

```typescript
new RebarClient(config: RebarClientConfig)
```

**Config Options:**
- `baseUrl`: Base URL of Rebar API
- `serviceId`: Your service identifier
- `tenant`: Tenant ID (default: "default")
- `timeout`: Request timeout in ms (default: 10000)

#### Methods

- `check(request: CheckRequest): Promise<boolean>`
- `explain(request: CheckRequest): Promise<ExplainResponse>`
- `createTuple(tuple: RelTuple): Promise<void>`
- `deleteTuple(tuple: RelTuple): Promise<void>`
- `batchCreateTuples(tuples: RelTuple[]): Promise<void>`
- `getActorPermissions(actorType: string, actorId: string): Promise<ActorPermissionsResponse>`
- `getActorGroups(actorType: string, actorId: string): Promise<ActorGroupsResponse>`
- `getAuditLogs(params?): Promise<AuditLogsResponse>`
- `getSchema(): Promise<any>`
- `setTenant(tenant: string): void`

## Building

```bash
npm install
npm run build
```

## License

MIT
