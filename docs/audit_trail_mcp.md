# Audit Trail MCP Tool

This document describes the `ListUserChangesTool` MCP tool that provides AI assistants with access to the PaperTrail audit log.

## Overview

The `ListUserChangesTool` allows users to query their own changes from the PaperTrail audit log through the MCP interface. The tool formats PaperTrail's hashdiff format into human-readable output optimized for LLM consumption.

## PaperTrail Configuration

The application uses the following gems:
- **paper_trail** (~> 17.0) - Main audit logging gem
- **paper_trail-hashdiff** (~> 0.1.3) - Efficient diff storage for nested objects
- **hashdiff** (~> 1.2) - Underlying diff library

Configuration in `config/initializers/paper_trail.rb`:
```ruby
require "paper_trail_hashdiff"
PaperTrail.config.object_changes_adapter = PaperTrailHashDiff.new
```

## Hashdiff Format

The `paper_trail-hashdiff` gem stores changes using the hashdiff format, which is more storage-efficient than storing full before/after values, especially for JSON/JSONB columns.

### Format Structure

Each change is represented as an array:
- `["~", path, old_value, new_value]` - Modified value
- `["+", path, value]` - Added value
- `["-", path, value]` - Removed value

Where:
- **Operator**: First element (`~`, `+`, or `-`)
- **Path**: Array of keys representing nested location (empty array for top-level)
- **Values**: Old and new values for modifications, single value for additions/deletions

### Examples

**Simple field change:**
```ruby
{"state" => [["~", [], nil, "new"]]}
# Translates to: "state changed from nil to 'new'"
```

**Nested JSON change:**
```ruby
{
  "custom_values" => [
    ["~", [:name], "abc", "def"],
    ["-", [:tags, 1], "b"],
    ["+", [:tags, 1], "c"]
  ]
}
# Translates to:
# - custom_values[name]: "abc" → "def"
# - custom_values[tags][1]: removed "b"
# - custom_values[tags][1]: added "c"
```

**Timestamp update:**
```ruby
{"updated_at" => [["~", [], "2025-11-03T21:15:55.715Z", "2025-11-03T21:15:55.736Z"]]}
# Translates to: "updated_at changed from 2025-11-03T21:15:55.715Z to 2025-11-03T21:15:55.736Z"
```

## Tool Usage

### Parameters

- **start_time** (optional): ISO8601 datetime string (e.g., "2025-11-03T00:00:00Z")
  - Defaults to 24 hours ago
- **end_time** (optional): ISO8601 datetime string
  - Defaults to current time
- **limit** (optional): Maximum number of versions to return
  - Default: 100

### Example Requests

```
"What changes have I made in the last 24 hours?"
# Uses default parameters

"Show me all my changes from 2025-11-01 to 2025-11-03"
# Specifies custom time range

"What have I changed in the last week?"
# AI assistant will calculate start_time as 7 days ago
```

## Output Format

The tool returns a formatted string with:

1. **Summary**: Count and time range
2. **Per-version details**:
   - Timestamp
   - Action (create, update, destroy)
   - Item Type (Task, Scope, Project, etc.)
   - Item ID
   - Formatted changes (translated from hashdiff)

### Example Output

```
Found 3 change(s) by john_doe between 2025-11-03 00:00 and 2025-11-04 00:00:

Timestamp: 2025-11-03 21:15
Action: update
Item Type: Task
Item ID: 42

Changes:
  state:
    Modified value: nil → "new"
  updated_at:
    Modified value: "2025-11-03T21:15:55.715Z" → "2025-11-03T21:15:55.736Z"

---

Timestamp: 2025-11-03 18:30
Action: create
Item Type: Task
Item ID: 43

Changes:
  name:
    Modified value: nil → "Fix login bug"
  project_id:
    Modified value: nil → 5

---

...
```

## Implementation Details

### Authentication & Scoping

- Uses `current_user` from MCP authentication context
- Queries PaperTrail::Version where `whodunnit = current_user.id.to_s`
- Only returns changes made by the authenticated user

### Database Query

```ruby
PaperTrail::Version
  .where(whodunnit: current_user.id.to_s)
  .where(created_at: start_datetime..end_datetime)
  .order(created_at: :desc)
  .limit(limit)
```

### Hashdiff Translation

The tool translates hashdiff format to human-readable text:

1. **Path formatting**: `[:custom_values, :tags, 1]` → `[custom_values][tags][1]`
2. **Value formatting**:
   - `nil` → "nil"
   - Strings > 100 chars truncated with "..."
   - Large hashes/arrays shown as "{...}" or "[...]"
3. **Operator translation**:
   - `~` → "Modified"
   - `+` → "Added"
   - `-` → "Removed"

## Integration with ApplicationTool

The tool inherits from `ApplicationTool` and uses:
- `current_user` for authentication
- `format_user(user)` for user display names
- `format_datetime(datetime)` for consistent timestamp formatting

## Testing

### Manual Testing

```bash
# Start Rails console
docker compose exec rails bash -lc "bin/rails console"

# Create a test change
user = User.first
task = Task.first
PaperTrail.request(whodunnit: user.id) do
  task.update(name: "Test change")
end

# Query versions
PaperTrail::Version.where(whodunnit: user.id.to_s).last
```

### Through MCP

Use the MCP inspector or an AI assistant to test:
```
"What changes have I made today?"
```

## Related Files

- **Tool**: `app/tools/list_user_changes_tool.rb`
- **PaperTrail Config**: `config/initializers/paper_trail.rb`
- **Migrations**: 
  - `db/migrate/*_create_versions.rb`
  - `db/migrate/*_add_object_changes_to_versions.rb`
- **ApplicationController**: Sets `whodunnit` via `before_action :set_paper_trail_whodunnit`

## Future Enhancements

Potential improvements:
- Filter by item type (e.g., only Task changes)
- Filter by action type (create, update, destroy)
- Group changes by item
- Diff visualization for complex nested changes
- Export to CSV or JSON
