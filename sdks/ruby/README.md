# Rebar SDK - Ruby

Official Ruby SDK for Rebar ReBAC authorization service.

## Installation

Add to your Gemfile:

```ruby
gem 'rebar-sdk'
```

Or install directly:

```bash
gem install rebar-sdk
```

## Usage

### Basic Setup

```ruby
require 'rebar'

client = Rebar::Client.new(
  base_url: 'http://localhost:3000',
  service_id: 'my-app',
  tenant: 'default'
)
```

### Check Permissions

```ruby
# Check if user can edit a document
allowed = client.check(
  actor: 'user',
  actor_id: 'alice',
  permission: 'can_edit',
  subject: 'doc',
  subject_id: 'doc-123'
)

if allowed
  puts 'Alice can edit doc-123'
end
```

### Get Explanation

```ruby
result = client.explain(
  actor: 'user',
  actor_id: 'alice',
  permission: 'viewer',
  subject: 'document',
  subject_id: 'doc-123'
)

puts "Allowed: #{result['allow']}"
puts "Path: #{result['path']}"
```

### Manage Relationships

```ruby
# Grant permission
client.create_tuple(
  subject: 'doc',
  id: 'doc-123',
  relation: 'editor',
  actor: 'user',
  actor_id: 'alice'
)

# Revoke permission
client.delete_tuple(
  subject: 'doc',
  id: 'doc-123',
  relation: 'editor',
  actor: 'user',
  actor_id: 'alice'
)

# Batch create
client.batch_create_tuples([
  { subject: 'doc', id: 'doc-1', relation: 'viewer', actor: 'user', actor_id: 'alice' },
  { subject: 'doc', id: 'doc-2', relation: 'editor', actor: 'user', actor_id: 'bob' }
])
```

### Get Actor Permissions

```ruby
permissions = client.actor_permissions('user', 'alice')

puts "Total permissions: #{permissions['total_permissions']}"
puts "Direct: #{permissions['direct_count']}"
puts "Group: #{permissions['group_count']}"
puts "Inherited: #{permissions['inherited_count']}"

permissions['resources'].each do |resource|
  puts "\n#{resource['resource']}:"
  puts "  Permissions: #{resource['permissions'].map { |p| p['permission'] }}"
  puts "  Actions: #{resource['actions']}"
end
```

### Get Group Memberships

```ruby
groups = client.actor_groups('user', 'alice')

groups['memberships'].each do |membership|
  puts "#{membership['group']} as #{membership['role']}"
end
```

### Audit Logs

```ruby
logs = client.audit_logs(
  page: 1,
  per_page: 50,
  subject: 'doc:123',
  action: 'create'
)

logs['logs'].each do |log|
  puts "#{log['action']}: #{log['subject']}:#{log['subject_id']} by #{log['performed_by']}"
end
```

### Rails Integration

```ruby
# config/initializers/rebar.rb
Rails.configuration.rebar = Rebar::Client.new(
  base_url: ENV['REBAR_URL'],
  service_id: 'my-rails-app',
  tenant: 'default'
)

# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  def rebar
    Rails.configuration.rebar
  end

  def authorize_action!(permission, subject, subject_id)
    unless rebar.check(
      actor: 'user',
      actor_id: current_user.id,
      permission: permission,
      subject: subject,
      subject_id: subject_id
    )
      raise Rebar::ForbiddenError, "You don't have permission to #{permission}"
    end
  end
end

# app/controllers/documents_controller.rb
class DocumentsController < ApplicationController
  before_action :set_document, only: [:show, :edit, :update]

  def show
    authorize_action!('can_view', 'doc', @document.id)
    # ... render document
  end

  def edit
    authorize_action!('can_edit', 'doc', @document.id)
    # ... render edit form
  end

  private

  def set_document
    @document = Document.find(params[:id])
  end
end
```

### Multi-Tenant Support

```ruby
# Change tenant dynamically
client.tenant = 'tenant-123'

# All subsequent requests use the new tenant
allowed = client.check(...)
```

### Error Handling

```ruby
begin
  client.check(
    actor: 'user',
    actor_id: 'alice',
    permission: 'can_edit',
    subject: 'doc',
    subject_id: 'doc-123'
  )
rescue Rebar::UnauthorizedError => e
  puts "Authentication failed: #{e.message}"
rescue Rebar::ForbiddenError => e
  puts "Access denied: #{e.message}"
rescue Rebar::NotFoundError => e
  puts "Resource not found: #{e.message}"
rescue Rebar::APIError => e
  puts "API error: #{e.message}"
end
```

## API Reference

### `Rebar::Client`

#### Constructor

```ruby
Rebar::Client.new(
  base_url: String,
  service_id: String,
  tenant: String (default: "default"),
  timeout: Integer (default: 10)
)
```

#### Methods

- `check(actor:, actor_id:, permission:, subject:, subject_id:) → Boolean`
- `explain(actor:, actor_id:, permission:, subject:, subject_id:) → Hash`
- `create_tuple(subject:, id:, relation:, actor:, actor_id:, actor_rel: nil) → Hash`
- `delete_tuple(subject:, id:, relation:, actor:, actor_id:, actor_rel: nil) → Hash`
- `batch_create_tuples(tuples) → Hash`
- `batch_delete_tuples(tuples) → Hash`
- `actor_permissions(actor_type, actor_id) → Hash`
- `actor_groups(actor_type, actor_id) → Hash`
- `audit_logs(page:, per_page:, subject:, actor:, action:) → Hash`
- `schema() → Hash`
- `tenant=(new_tenant)`

## Development

```bash
bundle install
bundle exec rspec
```

## License

MIT
