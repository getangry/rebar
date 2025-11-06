# Rebar API Usage Guide

Rebar is a Relationship-Based Access Control (ReBAC) system that provides fine-grained authorization through relationship graphs. This guide shows you how to use the API with both `curl` and Ruby.

## Table of Contents

- [Overview](#overview)
- [Authentication](#authentication)
- [API Endpoints](#api-endpoints)
  - [Create Relationship](#create-relationship)
  - [Delete Relationship](#delete-relationship)
  - [Check Permission](#check-permission)
  - [Explain Permission](#explain-permission)
  - [Batch Operations](#batch-operations)
- [Common Use Cases](#common-use-cases)
- [Schema](#schema)
- [Multi-Tenancy](#multi-tenancy)

## Overview

Rebar determines permissions by traversing a graph of relationships between entities. Instead of directly assigning permissions, you create relationships that imply permissions.

**Base URL:** `http://localhost:3000`

**Content Type:** All requests require `Content-Type: application/json`

## Authentication

All requests require service authentication via the `X-Service-Id` header.

**Development Mode:** Any non-empty service ID is accepted.

```bash
# curl
curl -H "X-Service-Id: dev" ...

# Ruby
require 'net/http'
require 'json'

def api_request(method, path, body = nil)
  uri = URI("http://localhost:3000#{path}")
  http = Net::HTTP.new(uri.host, uri.port)

  request = case method
  when :post then Net::HTTP::Post.new(uri.path)
  when :delete then Net::HTTP::Delete.new(uri.path)
  when :get then Net::HTTP::Get.new(uri.path)
  end

  request['Content-Type'] = 'application/json'
  request['X-Service-Id'] = 'dev'
  request['X-Tenant'] = 'default'

  request.body = body.to_json if body

  response = http.request(request)
  JSON.parse(response.body) rescue response.body
end
```

## API Endpoints

### Create Relationship

Create a relationship tuple between a subject and an object.

**Endpoint:** `POST /tuples`

**Parameters:**
- `subject` (string, required) - Subject namespace (e.g., "doc", "folder", "group")
- `id` (string, required) - Object identifier
- `relation` (string, required) - Relation type (e.g., "owner", "editor", "viewer", "member")
- `actor` (string, required) - Actor namespace (e.g., "user", "group")
- `actor_id` (string, required) - Actor identifier
- `actor_rel` (string, optional) - Actor relation for group membership (e.g., "member")

#### curl Example

```bash
# Make alice the owner of document "report-1"
curl -X POST http://localhost:3000/tuples \
  -H "Content-Type: application/json" \
  -H "X-Service-Id: dev" \
  -H "X-Tenant: default" \
  -d '{
    "subject": "doc",
    "id": "report-1",
    "relation": "owner",
    "actor": "user",
    "actor_id": "alice"
  }'
```

#### Ruby Example

```ruby
# Make alice the owner of document "report-1"
api_request(:post, '/tuples', {
  subject: 'doc',
  id: 'report-1',
  relation: 'owner',
  actor: 'user',
  actor_id: 'alice'
})
# => {"ok"=>true}

# Add bob to the engineering group
api_request(:post, '/tuples', {
  subject: 'group',
  id: 'engineering',
  relation: 'member',
  actor: 'user',
  actor_id: 'bob'
})

# Give engineering group viewer access to a folder
api_request(:post, '/tuples', {
  subject: 'folder',
  id: 'projects',
  relation: 'viewer',
  actor: 'group',
  actor_id: 'engineering',
  actor_rel: 'member'
})
```

---

### Delete Relationship

Remove a relationship tuple.

**Endpoint:** `DELETE /tuples`

**Parameters:** Same as Create Relationship

#### curl Example

```bash
# Remove alice's ownership of document "report-1"
curl -X DELETE http://localhost:3000/tuples \
  -H "Content-Type: application/json" \
  -H "X-Service-Id: dev" \
  -H "X-Tenant: default" \
  -d '{
    "subject": "doc",
    "id": "report-1",
    "relation": "owner",
    "actor": "user",
    "actor_id": "alice"
  }'
```

#### Ruby Example

```ruby
# Remove alice's ownership of document "report-1"
api_request(:delete, '/tuples', {
  subject: 'doc',
  id: 'report-1',
  relation: 'owner',
  actor: 'user',
  actor_id: 'alice'
})
# => {"ok"=>true}
```

---

### Check Permission

Check if a subject has a specific permission on an object.

**Endpoint:** `POST /auth/check`

**Parameters:**
- `actor` (string, required) - Actor namespace
- `actor_id` (string, required) - Actor identifier
- `permission` (string, required) - Permission to check (e.g., "owner", "editor", "viewer")
- `subject` (string, required) - Subject namespace
- `subject_id` (string, required) - Subject identifier

**Response:**
- `allow` (boolean) - `true` if permission is granted, `false` otherwise

#### curl Example

```bash
# Check if alice can view document "report-1"
curl -X POST http://localhost:3000/auth/check \
  -H "Content-Type: application/json" \
  -H "X-Service-Id: dev" \
  -H "X-Tenant: default" \
  -d '{
    "actor": "user",
    "actor_id": "alice",
    "permission": "viewer",
    "subject": "doc",
    "subject_id": "report-1"
  }'
```

#### Ruby Example

```ruby
# Check if alice can view document "report-1"
result = api_request(:post, '/auth/check', {
  actor: 'user',
  actor_id: 'alice',
  permission: 'viewer',
  subject: 'doc',
  subject_id: 'report-1'
})

if result['allow']
  puts "Access granted!"
else
  puts "Access denied!"
end
```

---

### Explain Permission

Get detailed explanation of how a permission is granted (or denied).

**Endpoint:** `POST /auth/explain`

**Parameters:** Same as Check Permission

**Response:**
- `allow` (boolean) - `true` if permission is granted
- `path` (array, optional) - Array showing the permission resolution path if granted

#### curl Example

```bash
# Get explanation for why alice can view document "report-1"
curl -X POST http://localhost:3000/auth/explain \
  -H "Content-Type: application/json" \
  -H "X-Service-Id: dev" \
  -H "X-Tenant: default" \
  -d '{
    "actor": "user",
    "actor_id": "alice",
    "permission": "viewer",
    "subject": "doc",
    "subject_id": "report-1"
  }'
```

#### Ruby Example

```ruby
# Get explanation for alice's viewer permission
result = api_request(:post, '/auth/explain', {
  actor: 'user',
  actor_id: 'alice',
  permission: 'viewer',
  subject: 'doc',
  subject_id: 'report-1'
})

if result['allow']
  puts "Access granted via path:"
  result['path'].each do |step|
    puts "  -> #{step}"
  end
else
  puts "Access denied (no permission path found)"
end
```

---

### Batch Operations

Create or delete multiple relationships in a single request.

**Endpoints:**
- `POST /tuples/batch` - Create multiple relationships
- `DELETE /tuples/batch` - Delete multiple relationships

**Parameters:**
- `tuples` (array, required) - Array of tuple objects (same structure as single operations)

**Response:**
- `ok` (boolean)
- `count` (integer) - Number of tuples processed

#### curl Example

```bash
# Create multiple relationships at once
curl -X POST http://localhost:3000/tuples/batch \
  -H "Content-Type: application/json" \
  -H "X-Service-Id: dev" \
  -H "X-Tenant: default" \
  -d '{
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
        "subject": "folder",
        "id": "eng-docs",
        "relation": "editor",
        "actor": "group",
        "actor_id": "engineering",
        "actor_rel": "member"
      }
    ]
  }'
```

#### Ruby Example

```ruby
# Create organizational structure in one request
api_request(:post, '/tuples/batch', {
  tuples: [
    # Add team members
    { ns: 'group', id: 'frontend', relation: 'member', actor: 'user', actor_id: 'alice' },
    { ns: 'group', id: 'frontend', relation: 'member', actor: 'user', actor_id: 'bob' },

    # Nest groups
    { ns: 'group', id: 'engineering', relation: 'member', actor: 'group', actor_id: 'frontend' },

    # Give engineering edit access to folder
    { ns: 'folder', id: 'projects', relation: 'editor', actor: 'group', actor_id: 'engineering', actor_rel: 'member' }
  ]
})
# => {"ok"=>true, "count"=>4}
```

---

## Common Use Cases

### 1. Document Ownership

```ruby
# Alice creates a document and becomes the owner
api_request(:post, '/tuples', {
  subject: 'doc',
  id: 'quarterly-report',
  relation: 'owner',
  actor: 'user',
  actor_id: 'alice'
})

# Check alice's permissions (owner includes editor and viewer)
api_request(:post, '/auth/check', {
  actor: 'user',
  actor_id: 'alice',
  permission: 'viewer',
  subject: 'doc',
  subject_id: 'quarterly-report'
})
# => {"allow"=>true}
```

### 2. Sharing a Document

```bash
# Give bob editor access to alice's document
curl -X POST http://localhost:3000/tuples \
  -H "Content-Type: application/json" \
  -H "X-Service-Id: dev" \
  -d '{
    "subject": "doc",
    "id": "quarterly-report",
    "relation": "editor",
    "actor": "user",
    "actor_id": "bob"
  }'
```

### 3. Folder Hierarchy with Inheritance

```ruby
# Create folder structure: root/company/engineering/
api_request(:post, '/tuples/batch', {
  tuples: [
    # Set up folder hierarchy
    { ns: 'folder', id: 'company', relation: 'parent', actor: 'folder', actor_id: 'root' },
    { ns: 'folder', id: 'engineering', relation: 'parent', actor: 'folder', actor_id: 'company' },

    # Alice owns root folder
    { ns: 'folder', id: 'root', relation: 'owner', actor: 'user', actor_id: 'alice' },

    # Document in engineering folder
    { ns: 'doc', id: 'tech-spec', relation: 'parent', actor: 'folder', actor_id: 'engineering' }
  ]
})

# Alice can view the tech-spec through folder ownership inheritance
api_request(:post, '/auth/check', {
  actor: 'user',
  actor_id: 'alice',
  permission: 'viewer',
  subject: 'doc',
  subject_id: 'tech-spec'
})
# => {"allow"=>true}
```

### 4. Group-Based Permissions

```bash
# Set up team-based access control
curl -X POST http://localhost:3000/tuples/batch \
  -H "Content-Type: application/json" \
  -H "X-Service-Id: dev" \
  -d '{
    "tuples": [
      {
        "subject": "group",
        "id": "marketing",
        "relation": "member",
        "actor": "user",
        "actor_id": "charlie"
      },
      {
        "subject": "folder",
        "id": "campaigns",
        "relation": "owner",
        "actor": "group",
        "actor_id": "marketing",
        "actor_rel": "member"
      },
      {
        "subject": "doc",
        "id": "q4-campaign",
        "relation": "parent",
        "actor": "folder",
        "actor_id": "campaigns"
      }
    ]
  }'

# Charlie can access q4-campaign through:
# 1. charlie is member of marketing group
# 2. marketing group owns campaigns folder
# 3. q4-campaign inherits from campaigns folder
```

### 5. Revoking Access

```ruby
# Remove bob's editor access to a document
api_request(:delete, '/tuples', {
  subject: 'doc',
  id: 'quarterly-report',
  relation: 'editor',
  actor: 'user',
  actor_id: 'bob'
})

# Verify bob no longer has editor access
result = api_request(:post, '/auth/check', {
  actor: 'user',
  actor_id: 'bob',
  permission: 'editor',
  subject: 'doc',
  subject_id: 'quarterly-report'
})
# => {"allow"=>false}
```

### 6. Nested Group Membership

```ruby
# Create organizational hierarchy
api_request(:post, '/tuples/batch', {
  tuples: [
    # alice is in frontend team
    { ns: 'group', id: 'frontend', relation: 'member', actor: 'user', actor_id: 'alice' },

    # frontend team is part of engineering department
    { ns: 'group', id: 'engineering', relation: 'member', actor: 'group', actor_id: 'frontend' },

    # engineering department is part of company-wide group
    { ns: 'group', id: 'all-staff', relation: 'member', actor: 'group', actor_id: 'engineering' },

    # Company handbook visible to all staff
    { ns: 'doc', id: 'handbook', relation: 'viewer', actor: 'group', actor_id: 'all-staff', actor_rel: 'member' }
  ]
})

# Alice can view handbook through nested group membership
api_request(:post, '/auth/check', {
  actor: 'user',
  actor_id: 'alice',
  permission: 'viewer',
  subject: 'doc',
  subject_id: 'handbook'
})
# => {"allow"=>true}
```

---

## Schema

Rebar uses a schema to define types and their relations. The default schema supports:

### Types

- **user** - Base user entity (no relations)
- **group** - Groups with nestable membership
- **folder** - Hierarchical folders with ownership
- **doc** - Documents with inherited permissions

### Relations

#### group
- `member`: ["user", "group"] - Users and groups can be members

#### folder
- `parent`: ["folder"] - Folder can have parent folder
- `owner`: ["user", "group"] - Direct ownership
- `editor`: ["owner", "group#editor"] - Editors + group editors
- `viewer`: ["editor", "group#viewer"] - Viewers + editors + group viewers

#### doc
- `parent`: ["folder"] - Document belongs to folder
- `owner`: ["user", "group"] - Direct ownership
- `editor`: ["owner", "parent->editor"] - Owners + inherited from parent folder
- `viewer`: ["editor", "parent->viewer"] - Editors + inherited from parent folder

### Permission Hierarchy

For both folders and documents:
- `owner` > `editor` > `viewer`
- Owners automatically have editor and viewer permissions
- Editors automatically have viewer permissions

---

## Multi-Tenancy

Rebar supports multi-tenancy through the `X-Tenant` header. Each tenant has completely isolated data.

```bash
# Create relationship in tenant "acme-corp"
curl -X POST http://localhost:3000/tuples \
  -H "Content-Type: application/json" \
  -H "X-Service-Id: dev" \
  -H "X-Tenant: acme-corp" \
  -d '{
    "subject": "doc",
    "id": "report-1",
    "relation": "owner",
    "actor": "user",
    "actor_id": "alice"
  }'

# Check permission in tenant "acme-corp"
curl -X POST http://localhost:3000/auth/check \
  -H "Content-Type: application/json" \
  -H "X-Service-Id: dev" \
  -H "X-Tenant: acme-corp" \
  -d '{
    "actor": "user",
    "actor_id": "alice",
    "permission": "owner",
    "subject": "doc",
    "subject_id": "report-1"
  }'
# => {"allow": true}

# Same user in different tenant has no access
curl -X POST http://localhost:3000/auth/check \
  -H "Content-Type: application/json" \
  -H "X-Service-Id: dev" \
  -H "X-Tenant: globex-inc" \
  -d '{
    "actor": "user",
    "actor_id": "alice",
    "permission": "owner",
    "subject": "doc",
    "subject_id": "report-1"
  }'
# => {"allow": false}
```

---

## Complete Ruby Client Example

```ruby
require 'net/http'
require 'json'

class RebarClient
  def initialize(base_url: 'http://localhost:3000', service_id: 'dev', tenant: 'default')
    @base_url = base_url
    @service_id = service_id
    @tenant = tenant
  end

  def create_relationship(ns:, id:, relation:, actor:, actor_id:, actor_rel: nil)
    request(:post, '/tuples', {
      subject: ns,
      id: id,
      relation: relation,
      actor: subj_ns,
      actor_id: subj_id,
      actor_rel: subj_rel
    }.compact)
  end

  def delete_relationship(ns:, id:, relation:, actor:, actor_id:, actor_rel: nil)
    request(:delete, '/tuples', {
      subject: ns,
      id: id,
      relation: relation,
      actor: subj_ns,
      actor_id: subj_id,
      actor_rel: subj_rel
    }.compact)
  end

  def check_permission(actor:, actor_id:, permission:, subject:, subject_id:)
    result = request(:post, '/auth/check', {
      actor: subj_ns,
      actor_id: subj_id,
      permission: permission,
      subject: obj_ns,
      subject_id: obj_id
    })
    result['allow']
  end

  def explain_permission(actor:, actor_id:, permission:, subject:, subject_id:)
    request(:post, '/auth/explain', {
      actor: subj_ns,
      actor_id: subj_id,
      permission: permission,
      subject: obj_ns,
      subject_id: obj_id
    })
  end

  def batch_create(tuples)
    request(:post, '/tuples/batch', { tuples: tuples })
  end

  def batch_delete(tuples)
    request(:delete, '/tuples/batch', { tuples: tuples })
  end

  private

  def request(method, path, body = nil)
    uri = URI("#{@base_url}#{path}")
    http = Net::HTTP.new(uri.host, uri.port)

    request = case method
    when :post then Net::HTTP::Post.new(uri.path)
    when :delete then Net::HTTP::Delete.new(uri.path)
    when :get then Net::HTTP::Get.new(uri.path)
    end

    request['Content-Type'] = 'application/json'
    request['X-Service-Id'] = @service_id
    request['X-Tenant'] = @tenant

    request.body = body.to_json if body

    response = http.request(request)
    JSON.parse(response.body)
  rescue JSON::ParserError
    response.body
  end
end

# Usage
client = RebarClient.new

# Create a document ownership
client.create_relationship(
  subject: 'doc',
  id: 'my-report',
  relation: 'owner',
  actor: 'user',
  actor_id: 'alice'
)

# Check if alice can view it
if client.check_permission(
  actor: 'user',
  actor_id: 'alice',
  permission: 'viewer',
  subject: 'doc',
  subject_id: 'my-report'
)
  puts "Alice has viewer access!"
end

# Get explanation
explanation = client.explain_permission(
  actor: 'user',
  actor_id: 'alice',
  permission: 'viewer',
  subject: 'doc',
  subject_id: 'my-report'
)

puts "Permission path: #{explanation['path']}"

# Revoke access
client.delete_relationship(
  subject: 'doc',
  id: 'my-report',
  relation: 'owner',
  actor: 'user',
  actor_id: 'alice'
)
```

---

## Error Responses

All errors return appropriate HTTP status codes with JSON error messages:

```json
{
  "error": "auth.check denied"
}
```

**Common Error Status Codes:**
- `403 Forbidden` - Missing or invalid authentication, or insufficient permissions
- `422 Unprocessable Entity` - Invalid request parameters
- `500 Internal Server Error` - Server error

---

## Best Practices

1. **Use Batch Operations**: When creating multiple relationships, use batch endpoints to reduce network overhead

2. **Check Before Modify**: Use `/auth/check` before performing sensitive operations in your application

3. **Use Explain for Debugging**: When troubleshooting permissions, use `/auth/explain` to understand the resolution path

4. **Leverage Groups**: Use groups for team-based access control rather than individual user grants

5. **Folder Hierarchies**: Organize documents in folders to inherit permissions automatically

6. **Idempotent Operations**: Both create and delete operations are idempotent - safe to retry

7. **Multi-Tenant Isolation**: Always specify `X-Tenant` header for proper data isolation

---

## Support

For issues, questions, or contributions, please visit the project repository.
