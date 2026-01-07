# Soft Delete Migration Guide

## Quick Start

To apply the soft delete implementation to your database:

### 1. Run the Migration

```bash
docker compose exec rails bash -lc "bin/rails db:migrate"
```

This will:
- Add `deleted_at` column to: projects, scopes, tasks, notes, links, attachments
- Create partial indexes on `deleted_at IS NULL` for optimal query performance

### 2. Verify Migration

```bash
docker compose exec rails bash -lc "bin/rails db:migrate:status"
```

Look for:
```
up     20251106000000  Add soft delete to models
```

### 3. Test in Rails Console

```bash
docker compose exec rails bash -lc "bin/rails console"
```

Test soft delete behavior:
```ruby
# Create and soft delete a project
project = Project.first
project.destroy              # Soft delete
project.deleted?             # => true
project.deleted_at           # => timestamp

# Query only active records (default)
Project.all                  # Excludes soft-deleted

# Query deleted records
Project.only_deleted.all     # Only soft-deleted

# Query all records
Project.with_deleted.all     # Both active and deleted

# Restore a deleted record
project.restore
project.deleted?             # => false
```

## What Changed

### Models
All 6 models now include `SoftDeletable` concern:
- ✅ Project
- ✅ Scope
- ✅ Task
- ✅ Note
- ✅ Link
- ✅ Attachment

### Controllers
Destroy actions now use soft delete:
- `@record.destroy` instead of `@record.destroy!`
- Flash message changed to "archived" instead of "destroyed"

### Queries
All queries automatically filter soft-deleted records:
- Controllers: `policy_scope(Model)` → filters deleted
- MCP Tools: `Model.all` → filters deleted
- Associations: `project.tasks` → filters deleted tasks

### UI
Delete buttons will now archive records instead of permanently removing them.

## Rollback (if needed)

If you need to rollback the migration:

```bash
docker compose exec rails bash -lc "bin/rails db:rollback"
```

This will:
- Remove `deleted_at` columns
- Drop the indexes

**Note:** Rollback will permanently delete any soft-deleted records!

## Performance

### Index Usage
```sql
-- Fast query using partial index
EXPLAIN SELECT * FROM projects WHERE deleted_at IS NULL;

-- Shows: Index Scan using index_projects_on_deleted_at
```

### Query Examples
```ruby
# Good: Uses index
Project.where(name: 'Test')  # Implicit: deleted_at IS NULL

# Good: Uses index
Project.where(deleted_at: nil)

# Slower: No index on deleted records
Project.only_deleted.where(name: 'Test')
```

## Troubleshooting

### Problem: "Record not found" error
**Solution:** Record may be soft-deleted
```ruby
# Instead of:
Project.find(id)  # Raises error if deleted

# Use:
Project.with_deleted.find(id)  # Finds even if deleted
```

### Problem: Need to permanently delete a record
**Solution:** Use `destroy!`
```ruby
project.destroy!  # Hard delete (permanent)
```

### Problem: Association returns deleted records
**Solution:** This shouldn't happen - associations respect default_scope
```ruby
# If you see deleted records:
project.tasks.with_deleted  # Must explicitly request deleted
```

## Production Deployment

### Before Deploying
1. ✅ Test migration in development
2. ✅ Test soft delete in development console
3. ✅ Verify index creation

### During Deployment
```bash
# Standard migration deployment
bin/rails db:migrate
```

### After Deployment
Monitor queries to ensure indexes are being used:
```sql
-- In PostgreSQL console
EXPLAIN ANALYZE SELECT * FROM projects;
-- Should show: Index Scan using index_projects_on_deleted_at
```

## See Also
- Complete documentation: `docs/soft_delete.md`
- Concern implementation: `app/models/concerns/soft_deletable.rb`
- Migration file: `db/migrate/20251106000000_add_soft_delete_to_models.rb`
