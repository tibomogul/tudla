# Soft Delete Implementation

## Overview

Soft delete preserves data history by marking records as deleted rather than permanently removing them from the database. Records are filtered from normal queries but remain available for auditing, recovery, and compliance purposes.

## Models with Soft Delete

The following 10 models include the `SoftDeletable` concern:

| Model | File | Notes |
|-------|------|-------|
| Project | `app/models/project.rb` | Includes Statesman state machine |
| Scope | `app/models/scope.rb` | |
| Task | `app/models/task.rb` | Includes Statesman state machine |
| Note | `app/models/note.rb` | |
| Link | `app/models/link.rb` | |
| Attachment | `app/models/attachment.rb` | |
| Organization | `app/models/organization.rb` | |
| Team | `app/models/team.rb` | |
| Report | `app/models/report.rb` | |
| ApiToken | `app/models/api_token.rb` | Dual-state: revocation + soft delete |

## Implementation

### SoftDeletable Concern

Location: `app/models/concerns/soft_deletable.rb`

```ruby
module SoftDeletable
  extend ActiveSupport::Concern

  included do
    scope :active, -> { where(deleted_at: nil) }
    scope :with_deleted, -> { unscope(where: :deleted_at) }
    scope :only_deleted, -> { unscope(where: :deleted_at).where.not(deleted_at: nil) }
  end

  def soft_delete
    update_column(:deleted_at, Time.current)
  end

  def restore
    update_column(:deleted_at, nil)
  end

  def deleted?
    deleted_at.present?
  end

  def destroy
    soft_delete
  end

  def destroy!
    super  # Hard delete
  end
end
```

### Key Design Decision: No default_scope

**There is NO `default_scope`.** All queries must explicitly use `.active` to filter soft-deleted records.

**Why:**
- Conflicts with Statesman's `ActiveRecordQueries` adapter (unique index checks fail)
- Causes issues with Rails 8 `insert_all` / `upsert` operations
- Causes problems with `after_commit` broadcasts during seeding
- Makes filtering explicit and intentional

### Database Schema

Each soft-deletable model has a `deleted_at` datetime column with a partial index:

```sql
ALTER TABLE projects ADD COLUMN deleted_at DATETIME;
CREATE INDEX index_projects_on_deleted_at ON projects (deleted_at) 
  WHERE deleted_at IS NULL;
```

The partial index only indexes non-deleted records, optimizing the most common queries.

**Migration file:** `db/migrate/20251106000000_add_soft_delete_to_models.rb`
- Uses `disable_ddl_transaction!` for production safety
- Creates indexes with `algorithm: :concurrently` to avoid table locks

## Usage

### Querying Records

```ruby
# REQUIRED: Explicitly use .active to exclude soft-deleted records
Project.active.all
Task.active.where(project_id: 1)

# Include soft-deleted records
Project.with_deleted.all

# Only soft-deleted records
Project.only_deleted.all

# WARNING: Without .active, soft-deleted records ARE included
Project.all  # Includes deleted records!
```

### Deleting Records

```ruby
# Soft delete (sets deleted_at timestamp)
project.destroy

# Hard delete (permanently removes from database)
project.destroy!
```

### Restoring Records

```ruby
project = Project.only_deleted.find(id)
project.restore  # Clears deleted_at
project.deleted?  # => false
```

## Integration Requirements

Because there is no `default_scope`, you **must explicitly use `.active`** in:

### Controllers
```ruby
# Via policy_scope (policies add .active)
@projects = policy_scope(Project)

# Direct queries
@tasks = Task.active.where(user_id: current_user.id)
```

### Policies
All Pundit policy scopes explicitly call `.active`:
```ruby
class ProjectPolicy::Scope
  def resolve
    # ... permission logic ...
    scope.active.where(id: project_ids)
  end
end
```

### MCP Tools
All MCP tools explicitly call `.active`:
```ruby
def call(limit: 50)
  projects = Project.active.limit(limit)
  # ...
end
```

### Associations
Associations do NOT automatically filter:
```ruby
# Must explicitly filter
project.tasks.active

# Without .active, includes deleted tasks
project.tasks
```

## Controller Behavior

Most controllers use soft delete (`destroy`):

| Controller | Method | Message |
|------------|--------|---------|
| ProjectsController | `destroy` | "archived" |
| ScopesController | `destroy` | "archived" |
| TasksController | `destroy` | "archived" |
| OrganizationsController | `destroy` | "archived" |
| TeamsController | `destroy` | "archived" |
| ReportsController | `destroy` | "archived" |
| ApiTokensController | `destroy` | "archived" |
| NotesController | `destroy` | "deleted" |
| LinksController | `destroy` | "deleted" |

**Exception:** `AttachmentsController` uses `destroy!` (hard delete) for file cleanup.

## Special Model Behaviors

### Statesman Integration (Task & Project)

Soft delete is fully compatible with Statesman's `ActiveRecordQueries` adapter:

```ruby
class Task < ApplicationRecord
  include Statesman::Adapters::ActiveRecordQueries[
    transition_class: TaskTransition,
    initial_state: :new
  ]
  include SoftDeletable  # After Statesman
end
```

**Combined usage:**
```ruby
Task.active.in_state(:in_progress)
Task.active.not_in_state(:done, :blocked)
Project.active.in_state(:green)
```

### ApiToken Dual-State

ApiToken combines revocation (`active` column) with soft deletion (`deleted_at` column):

```ruby
# Soft delete AND revoke
token.destroy  # Sets active=false AND deleted_at=Time.current

# Revoke only (token remains visible in list)
token.revoke!  # Sets active=false only

# Authentication checks both states
ApiToken.authenticate(token_string)  # Requires active=true AND deleted_at IS NULL
```

**Overridden `active` scope:**
```ruby
scope :active, -> { 
  where(deleted_at: nil)
    .where(active: true)
    .where("expires_at IS NULL OR expires_at > ?", Time.current) 
}
```

## Performance

### Partial Indexes

Partial indexes on `deleted_at IS NULL` ensure optimal performance:
- Only non-deleted records are indexed
- Queries for active records use the index efficiently
- Minimal storage overhead

### Query Performance

```ruby
# Fast: Uses partial index
Project.active.where(name: 'Test')

# Slower: No index on deleted records (full table scan)
Project.only_deleted.all
```

## Adding Soft Delete to New Models

### 1. Create Migration

```ruby
class AddSoftDeleteToMyModel < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :my_models, :deleted_at, :datetime
    add_index :my_models, :deleted_at, 
      where: "deleted_at IS NULL", 
      algorithm: :concurrently
  end
end
```

### 2. Include Concern

```ruby
class MyModel < ApplicationRecord
  include SoftDeletable
end
```

**For Statesman models**, include Statesman adapter first:
```ruby
class MyModel < ApplicationRecord
  include Statesman::Adapters::ActiveRecordQueries[
    transition_class: MyTransition,
    initial_state: :initial_state
  ]
  include SoftDeletable  # After Statesman
end
```

### 3. Update Controller

```ruby
def destroy
  @record.destroy  # Not destroy!
  redirect_to records_path, notice: "Record was successfully archived."
end
```

### 4. Update Policy Scope

```ruby
class MyModelPolicy::Scope
  def resolve
    scope.active.where(...)  # Add .active
  end
end
```

## Cleanup Old Records

To permanently delete old soft-deleted records:

```ruby
# In a rake task or console
Project.only_deleted
  .where('deleted_at < ?', 90.days.ago)
  .find_each(&:destroy!)
```

## Troubleshooting

### Record Not Found

If you get `ActiveRecord::RecordNotFound` for a deleted record:
```ruby
# Use with_deleted scope
record = Model.with_deleted.find(id)
```

### Deleted Records Appearing

If deleted records appear in queries, ensure `.active` is used:
```ruby
# Wrong
Project.where(team_id: 1)

# Correct
Project.active.where(team_id: 1)
```

### Permanently Delete a Record

```ruby
record.destroy!  # Hard delete (use with caution)
```

## Migration & Deployment

### Run Migration

```bash
docker compose exec rails bash -lc "bin/rails db:migrate"
```

### Verify Migration

```bash
docker compose exec rails bash -lc "bin/rails db:migrate:status"
```

### Test in Console

```ruby
# Soft delete
project = Project.first
project.destroy
project.deleted?  # => true

# Verify filtering
Project.active.count  # Excludes deleted
Project.with_deleted.count  # Includes deleted

# Restore
project.restore
project.deleted?  # => false
```

### Rollback (if needed)

```bash
docker compose exec rails bash -lc "bin/rails db:rollback"
```

**Warning:** Rollback will permanently delete any soft-deleted records!

## Benefits

- **Data Preservation:** Records are never permanently lost
- **Audit Trail:** Keep history of deleted records
- **Easy Recovery:** Restore accidentally deleted records
- **Performance:** Partial indexes ensure fast queries on active records
- **Statesman Compatible:** Full `ActiveRecordQueries` support
- **Rails 8 Compatible:** No conflicts with `insert_all` or broadcasts
- **Explicit:** `.active` scope makes filtering visible and intentional
