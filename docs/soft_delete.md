# Soft Delete Implementation

## Overview
Projects, Scopes, Tasks, Notes, Links, and Attachments use soft delete to preserve data history while removing records from normal queries.

## Implementation Details

### Database Schema
Each soft-deletable model has a `deleted_at` datetime column with a partial index:
```sql
ALTER TABLE projects ADD COLUMN deleted_at DATETIME;
CREATE INDEX index_projects_on_deleted_at ON projects (deleted_at) WHERE deleted_at IS NULL;
```

The partial index (`WHERE deleted_at IS NULL`) only indexes non-deleted records, optimizing the most common queries.

### SoftDeletable Concern
Location: `app/models/concerns/soft_deletable.rb`

**Features:**
- `scope :active` - Returns non-deleted records (must be explicitly used)
- `scope :with_deleted` - Include soft-deleted records in query
- `scope :only_deleted` - Return only soft-deleted records
- `soft_delete` - Mark record as deleted (sets `deleted_at` timestamp)
- `restore` - Restore a soft-deleted record (clears `deleted_at`)
- `deleted?` - Check if record is soft deleted
- `destroy` - Override to perform soft delete instead of hard delete
- `destroy!` - Hard delete (actually remove from database)

**IMPORTANT:** No `default_scope` - You must explicitly use `.active` in all queries

### Models with Soft Delete (10 total)
1. **Project** (`app/models/project.rb`)
2. **Scope** (`app/models/scope.rb`)
3. **Task** (`app/models/task.rb`)
4. **Note** (`app/models/note.rb`)
5. **Link** (`app/models/link.rb`)
6. **Attachment** (`app/models/attachment.rb`)
7. **Organization** (`app/models/organization.rb`)
8. **Team** (`app/models/team.rb`)
9. **Report** (`app/models/report.rb`)
10. **ApiToken** (`app/models/api_token.rb`) - Special behavior: dual-state with `active` column

## Usage

### Querying Records
```ruby
# MUST explicitly use .active scope to exclude soft-deleted records
Project.active.all                    # Only active projects
Task.active.where(project_id: 1)      # Only active tasks

# Include soft-deleted records
Project.with_deleted.all              # All projects (active + deleted)
Task.only_deleted.all                 # Only soft-deleted tasks
```

### Deleting Records
```ruby
# Soft delete (recommended)
project.destroy                # Sets deleted_at timestamp
task.destroy                   # Archived, still in database

# Hard delete (permanent removal)
project.destroy!               # Permanently removes from database
```

### Restoring Records
```ruby
# Find and restore a soft-deleted record
project = Project.only_deleted.find(id)
project.restore                # Clears deleted_at, makes it active again
```

## Controller Behavior

### Destroy Actions
Controllers use `destroy` (soft delete) instead of `destroy!`:
```ruby
# ProjectsController, ScopesController, TasksController
def destroy
  @record.destroy
  redirect_to records_path, notice: "Record was successfully archived."
end
```

### Index and Show Actions
All queries automatically filter soft-deleted records via `policy_scope`:
```ruby
def index
  @projects = policy_scope(Project)  # Only active projects
end

def show
  @project = Project.find(params[:id])  # Only finds active projects
end
```

## Policy Integration

Pundit policies automatically respect soft delete via the default scope:
```ruby
class ProjectPolicy::Scope
  def resolve
    # scope already filters soft-deleted via default_scope
    scope.where(id: accessible_project_ids)
  end
end
```

## MCP Tools Integration

MCP tools automatically filter soft-deleted records:
```ruby
# ListTasksTool
def call(...)
  tasks = Task.all           # default_scope filters deleted
  tasks = scope_tasks_by_user(tasks)
  format_tasks(tasks)
end
```

## Performance Considerations

### Indexes
Partial indexes on `deleted_at IS NULL` ensure optimal performance:
- Only non-deleted records are indexed
- Queries for active records use the index efficiently
- Minimal storage overhead

### Query Performance
```sql
-- Fast: Uses partial index
SELECT * FROM projects WHERE deleted_at IS NULL;

-- Also fast: Implicit default scope
SELECT * FROM projects;  -- Rails adds WHERE deleted_at IS NULL

-- Slower: Full table scan
SELECT * FROM projects WHERE deleted_at IS NOT NULL;  -- No index
```

## Associations

Soft delete automatically applies to associations:
```ruby
project.scopes     # Only active scopes (default_scope applies)
scope.tasks        # Only active tasks
```

## Broadcasts and Callbacks

After-commit callbacks still fire for soft delete:
```ruby
# Note model
after_commit :broadcast_note_update, on: [:destroy]

# When note.destroy is called (soft delete):
# 1. deleted_at is set
# 2. after_commit callback fires
# 3. Broadcast updates the UI
```

## Migration

To add soft delete to a new model:

1. **Create migration:**
```ruby
add_column :model_name, :deleted_at, :datetime
add_index :model_name, :deleted_at, where: "deleted_at IS NULL"
```

2. **Include concern in model:**
```ruby
class MyModel < ApplicationRecord
  include SoftDeletable
  # ... rest of model
end
```

3. **Update controller destroy action:**
```ruby
def destroy
  @record.destroy  # Use destroy, not destroy!
  redirect_to records_path, notice: "Record was successfully archived."
end
```

## Troubleshooting

### Record Not Found Error
If you get `ActiveRecord::RecordNotFound` for a deleted record:
```ruby
# Use with_deleted scope
record = Model.with_deleted.find(id)
```

### Accessing Deleted Records in Tests
```ruby
# In RSpec/test files
deleted_task = Task.only_deleted.find(id)
deleted_task.restore  # Make it active again
```

### Bypassing Soft Delete
```ruby
# To query all records including deleted
Model.with_deleted.where(...)

# To permanently delete
record.destroy!  # Use with caution!
```
