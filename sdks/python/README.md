# Rebar SDK - Python

Official Python SDK for Rebar ReBAC authorization service.

## Installation

```bash
pip install rebar-sdk
```

## Usage

### Basic Setup

```python
from rebar import RebarClient

client = RebarClient(
    base_url='http://localhost:3000',
    service_id='my-app',
    tenant='default'
)
```

### Check Permissions

```python
# Check if user can edit a document
allowed = client.check(
    actor='user',
    actor_id='alice',
    permission='can_edit',
    subject='doc',
    subject_id='doc-123'
)

if allowed:
    print('Alice can edit doc-123')
```

### Get Explanation

```python
result = client.explain(
    actor='user',
    actor_id='alice',
    permission='viewer',
    subject='document',
    subject_id='doc-123'
)

print(f"Allowed: {result['allow']}")
print(f"Path: {result.get('path')}")
```

### Manage Relationships

```python
# Grant permission
client.create_tuple(
    subject='doc',
    id='doc-123',
    relation='editor',
    actor='user',
    actor_id='alice'
)

# Revoke permission
client.delete_tuple(
    subject='doc',
    id='doc-123',
    relation='editor',
    actor='user',
    actor_id='alice'
)

# Batch create
client.batch_create_tuples([
    {'subject': 'doc', 'id': 'doc-1', 'relation': 'viewer',
     'actor': 'user', 'actor_id': 'alice'},
    {'subject': 'doc', 'id': 'doc-2', 'relation': 'editor',
     'actor': 'user', 'actor_id': 'bob'}
])
```

### Get Actor Permissions

```python
permissions = client.actor_permissions('user', 'alice')

print(f"Total permissions: {permissions['total_permissions']}")
print(f"Direct: {permissions['direct_count']}")
print(f"Group: {permissions['group_count']}")
print(f"Inherited: {permissions['inherited_count']}")

for resource in permissions['resources']:
    print(f"\n{resource['resource']}:")
    print(f"  Permissions: {[p['permission'] for p in resource['permissions']]}")
    print(f"  Actions: {resource['actions']}")
```

### Get Group Memberships

```python
groups = client.actor_groups('user', 'alice')

for membership in groups['memberships']:
    print(f"{membership['group']} as {membership['role']}")
```

### Audit Logs

```python
logs = client.audit_logs(
    page=1,
    per_page=50,
    subject='doc:123',
    action='create'
)

for log in logs['logs']:
    print(f"{log['action']}: {log['subject']}:{log['subject_id']} "
          f"by {log.get('performed_by')}")
```

### Django Integration

```python
# settings.py
from rebar import RebarClient

REBAR_CLIENT = RebarClient(
    base_url=os.getenv('REBAR_URL'),
    service_id='my-django-app',
    tenant='default'
)

# middleware.py
from django.conf import settings
from django.http import HttpResponseForbidden
from rebar import ForbiddenError

class RebarAuthorizationMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response
        self.client = settings.REBAR_CLIENT

    def __call__(self, request):
        request.rebar = self.client
        return self.get_response(request)

# views.py
from django.shortcuts import render, get_object_or_404
from rebar import ForbiddenError

def document_view(request, doc_id):
    document = get_object_or_404(Document, id=doc_id)

    # Check permission
    allowed = request.rebar.check(
        actor='user',
        actor_id=str(request.user.id),
        permission='can_view',
        subject='doc',
        subject_id=str(doc_id)
    )

    if not allowed:
        raise ForbiddenError("You don't have permission to view this document")

    return render(request, 'document.html', {'document': document})

# decorators.py
from functools import wraps
from django.http import HttpResponseForbidden
from rebar import ForbiddenError

def require_permission(permission, subject_type):
    def decorator(view_func):
        @wraps(view_func)
        def wrapper(request, *args, **kwargs):
            subject_id = kwargs.get('pk') or kwargs.get('id')

            allowed = request.rebar.check(
                actor='user',
                actor_id=str(request.user.id),
                permission=permission,
                subject=subject_type,
                subject_id=str(subject_id)
            )

            if not allowed:
                return HttpResponseForbidden(
                    f"You don't have permission: {permission}"
                )

            return view_func(request, *args, **kwargs)
        return wrapper
    return decorator

# Usage in views
@require_permission('can_edit', 'doc')
def edit_document(request, id):
    # ... edit document
    pass
```

### Flask Integration

```python
# app.py
from flask import Flask, g, request, abort
from rebar import RebarClient, ForbiddenError
import os

app = Flask(__name__)

rebar = RebarClient(
    base_url=os.getenv('REBAR_URL'),
    service_id='my-flask-app',
    tenant='default'
)

@app.before_request
def before_request():
    g.rebar = rebar

def require_permission(permission, subject_type, subject_id_param='id'):
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            subject_id = kwargs.get(subject_id_param)
            user_id = get_current_user_id()  # Your auth logic

            allowed = g.rebar.check(
                actor='user',
                actor_id=user_id,
                permission=permission,
                subject=subject_type,
                subject_id=subject_id
            )

            if not allowed:
                abort(403, description=f"Permission denied: {permission}")

            return f(*args, **kwargs)
        return decorated_function
    return decorator

@app.route('/documents/<id>')
@require_permission('can_view', 'doc', 'id')
def view_document(id):
    # ... render document
    pass
```

### Multi-Tenant Support

```python
# Change tenant dynamically
client.set_tenant('tenant-123')

# All subsequent requests use the new tenant
allowed = client.check(...)
```

### Error Handling

```python
from rebar import (
    RebarClient,
    UnauthorizedError,
    ForbiddenError,
    NotFoundError,
    APIError
)

try:
    allowed = client.check(
        actor='user',
        actor_id='alice',
        permission='can_edit',
        subject='doc',
        subject_id='doc-123'
    )
except UnauthorizedError as e:
    print(f"Authentication failed: {e}")
except ForbiddenError as e:
    print(f"Access denied: {e}")
except NotFoundError as e:
    print(f"Resource not found: {e}")
except APIError as e:
    print(f"API error: {e}")
```

## API Reference

### `RebarClient`

#### Constructor

```python
RebarClient(
    base_url: str,
    service_id: str,
    tenant: str = "default",
    timeout: int = 10
)
```

#### Methods

- `check(actor, actor_id, permission, subject, subject_id) → bool`
- `explain(actor, actor_id, permission, subject, subject_id) → Dict`
- `create_tuple(subject, id, relation, actor, actor_id, actor_rel=None) → Dict`
- `delete_tuple(subject, id, relation, actor, actor_id, actor_rel=None) → Dict`
- `batch_create_tuples(tuples) → Dict`
- `batch_delete_tuples(tuples) → Dict`
- `actor_permissions(actor_type, actor_id) → Dict`
- `actor_groups(actor_type, actor_id) → Dict`
- `audit_logs(page, per_page, subject, actor, action) → Dict`
- `schema() → Dict`
- `set_tenant(tenant)`

## Development

```bash
pip install -e ".[dev]"
pytest
black .
mypy rebar
```

## License

MIT
