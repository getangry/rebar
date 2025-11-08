# Rebar SDKs

Official SDKs for interacting with the Rebar ReBAC authorization service.

## Available SDKs

### TypeScript/JavaScript SDK
**Location:** `sdks/typescript/`
**Installation:** `npm install @rebar/sdk`
**Best for:** React, Node.js, Next.js, Vue, Angular applications

[View Documentation →](typescript/README.md)

```typescript
import { RebarClient } from '@rebar/sdk';

const client = new RebarClient({
  baseUrl: 'http://localhost:3000',
  serviceId: 'my-app',
  tenant: 'default'
});

const allowed = await client.check({
  actor: 'user',
  actorId: 'alice',
  permission: 'can_edit',
  subject: 'doc',
  subjectId: 'doc-123'
});
```

### Ruby SDK
**Location:** `sdks/ruby/`
**Installation:** `gem install rebar-sdk`
**Best for:** Ruby on Rails, Sinatra, Hanami applications

[View Documentation →](ruby/README.md)

```ruby
require 'rebar'

client = Rebar::Client.new(
  base_url: 'http://localhost:3000',
  service_id: 'my-app',
  tenant: 'default'
)

allowed = client.check(
  actor: 'user',
  actor_id: 'alice',
  permission: 'can_edit',
  subject: 'doc',
  subject_id: 'doc-123'
)
```

### Python SDK
**Location:** `sdks/python/`
**Installation:** `pip install rebar-sdk`
**Best for:** Django, Flask, FastAPI applications

[View Documentation →](python/README.md)

```python
from rebar import RebarClient

client = RebarClient(
    base_url='http://localhost:3000',
    service_id='my-app',
    tenant='default'
)

allowed = client.check(
    actor='user',
    actor_id='alice',
    permission='can_edit',
    subject='doc',
    subject_id='doc-123'
)
```

### Go SDK
**Location:** `sdks/go/`
**Installation:** `go get github.com/getangry/rebar/sdk/go`
**Best for:** Go microservices, API servers, CLI tools

[View Documentation →](go/README.md)

```go
import rebar "github.com/getangry/rebar/sdk/go"

client := rebar.NewClient(rebar.Config{
    BaseURL:   "http://localhost:3000",
    ServiceID: "my-app",
    Tenant:    "default",
})

allowed, err := client.Check(ctx, rebar.CheckRequest{
    Actor:      "user",
    ActorID:    "alice",
    Permission: "can_edit",
    Subject:    "doc",
    SubjectID:  "doc-123",
})
```

## Common Features

All SDKs provide the following functionality:

### Permission Checking
- **Check:** Verify if an actor has a permission on a subject
- **Explain:** Get the reasoning path for why a permission is granted

### Relationship Management
- **Create Tuple:** Grant permissions by creating relationships
- **Delete Tuple:** Revoke permissions by removing relationships
- **Batch Operations:** Efficiently manage multiple relationships at once

### Actor Queries
- **Actor Permissions:** Get all permissions an actor has across all resources
- **Actor Groups:** Get all groups an actor is a member of
- **Actions:** See what actions an actor can perform on each resource

### Audit & Compliance
- **Audit Logs:** Query all permission changes with filtering
- **Schema Information:** Retrieve the authorization schema

### Multi-Tenancy
- All SDKs support multi-tenant deployments via the `tenant` parameter
- Easily switch tenants for different parts of your application

## Quick Start Examples

### Basic Permission Check

Check if a user can perform an action:

**TypeScript:**
```typescript
const canEdit = await client.check({
  actor: 'user', actorId: 'alice',
  permission: 'can_edit',
  subject: 'doc', subjectId: 'doc-123'
});
```

**Ruby:**
```ruby
can_edit = client.check(
  actor: 'user', actor_id: 'alice',
  permission: 'can_edit',
  subject: 'doc', subject_id: 'doc-123'
)
```

**Python:**
```python
can_edit = client.check(
    actor='user', actor_id='alice',
    permission='can_edit',
    subject='doc', subject_id='doc-123'
)
```

**Go:**
```go
canEdit, _ := client.Check(ctx, rebar.CheckRequest{
    Actor: "user", ActorID: "alice",
    Permission: "can_edit",
    Subject: "doc", SubjectID: "doc-123",
})
```

### Grant Permission

Create a relationship to grant access:

**TypeScript:**
```typescript
await client.createTuple({
  subject: 'doc', id: 'doc-123',
  relation: 'editor',
  actor: 'user', actorId: 'alice'
});
```

**Ruby:**
```ruby
client.create_tuple(
  subject: 'doc', id: 'doc-123',
  relation: 'editor',
  actor: 'user', actor_id: 'alice'
)
```

**Python:**
```python
client.create_tuple(
    subject='doc', id='doc-123',
    relation='editor',
    actor='user', actor_id='alice'
)
```

**Go:**
```go
client.CreateTuple(ctx, rebar.RelTuple{
    Subject: "doc", ID: "doc-123",
    Relation: "editor",
    Actor: "user", ActorID: "alice",
})
```

### Get User Permissions

Retrieve all permissions for a user:

**TypeScript:**
```typescript
const perms = await client.getActorPermissions('user', 'alice');
console.log(`Total: ${perms.totalPermissions}`);
perms.resources.forEach(r => {
  console.log(`${r.resource}: ${r.actions.join(', ')}`);
});
```

**Ruby:**
```ruby
perms = client.actor_permissions('user', 'alice')
puts "Total: #{perms['total_permissions']}"
perms['resources'].each do |r|
  puts "#{r['resource']}: #{r['actions'].join(', ')}"
end
```

**Python:**
```python
perms = client.actor_permissions('user', 'alice')
print(f"Total: {perms['total_permissions']}")
for r in perms['resources']:
    print(f"{r['resource']}: {', '.join(r['actions'])}")
```

**Go:**
```go
perms, _ := client.ActorPermissions(ctx, "user", "alice")
fmt.Printf("Total: %d\n", perms.TotalPermissions)
for _, r := range perms.Resources {
    fmt.Printf("%s: %v\n", r.Resource, r.Actions)
}
```

## Performance

All SDKs are optimized for performance:

- **Sub-millisecond checks** for cached permissions
- **Batch operations** for efficient bulk updates
- **Connection pooling** and HTTP keep-alive
- **Automatic retries** with exponential backoff

Tested performance (1.3M tuples):
- Cache MISS: ~141ms
- Cache HIT: ~71-76ms
- Internal check: <1ms

## Development

### Building the SDKs

**TypeScript:**
```bash
cd sdks/typescript
npm install
npm run build
```

**Ruby:**
```bash
cd sdks/ruby
bundle install
```

**Python:**
```bash
cd sdks/python
pip install -e ".[dev]"
python setup.py build
```

**Go:**
```bash
cd sdks/go
go build
go test
```

## Contributing

Contributions are welcome! Please see each SDK's README for development setup and guidelines.

## License

All SDKs are released under the MIT License.

## Support

- **Documentation:** https://github.com/getangry/rebar
- **Issues:** https://github.com/getangry/rebar/issues
- **Discussions:** https://github.com/getangry/rebar/discussions
