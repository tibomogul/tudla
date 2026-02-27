# MCP Tools

## Architecture
- **Base class**: `ApplicationTool < MCP::Tool`
- **Pattern**: `self.call(server_context:, **args)` → creates instance → delegates to `#execute(**args)`
- **Response**: `#execute` returns plain text string; `ApplicationTool.call` wraps in `MCP::Tool::Response`
- **Errors**: Pundit::NotAuthorizedError and StandardError caught, logged, returned as error responses
- **Formatters**: `McpFormatters` concern (in `concerns/`) included in ApplicationTool

## Auth Flow
1. `McpController` authenticates Bearer token → sets `server_context[:user]`
2. `current_user` retrieves from `server_context[:user]`, raises if nil
3. `authorize(record, :action?)` delegates to Pundit policy
4. Scoping: `scope_tasks_by_user(tasks)` → `TaskPolicy::Scope.new(current_user, tasks).resolve`

## Helper Methods (ApplicationTool)
- `current_user` — Authenticated user from server_context (raises if missing)
- `authorize(record, query)` — Pundit authorization check
- `scope_tasks_by_user(tasks)` / `scope_scopes_by_user` / `scope_projects_by_user` — Policy scoping
- `call_tool(ToolClass, **args)` — Cross-tool calls with same server_context

## Formatters (McpFormatters concern)
Provides: `format_tasks`, `format_scopes`, `format_projects`, `format_task_details`, `format_scope_details`, `format_project_details`, `format_user`, `format_datetime`

## Tool Inventory (13 total)

| Tool | Domain | Read/Write | Description |
|------|--------|-----------|-------------|
| ListTasksTool | Task | Read | Filter by project, scope, user, state, in_today, limit |
| GetTaskTool | Task | Read | Full details with state history + allowed transitions |
| CreateTaskTool | Task | Write | Creates task, returns details via call_tool(GetTaskTool) |
| UpdateTaskTool | Task | Write | Updates attributes, returns full details |
| TransitionTaskStateTool | Task | Write | State machine transition with user_id metadata |
| AssignTaskTool | Task | Write | Assigns responsible_user with authorization |
| ListScopesTool | Scope | Read | Filter by project_id, limit |
| GetScopeTool | Scope | Read | Details with tasks + completion percentage |
| CreateScopeTool | Scope | Write | Creates scope in project |
| UpdateScopeTool | Scope | Write | Updates scope attributes |
| ListProjectsTool | Project | Read | All projects accessible to user |
| GetProjectTool | Project | Read | Details with scopes and tasks |
| ListUserChangesTool | Audit | Read | PaperTrail versions with time range + team filtering |

## Adding a New Tool
```ruby
class MyNewTool < ApplicationTool
  description "What this tool does"

  annotations(
    title: "Human-Readable Name",
    read_only_hint: true  # false for mutations
  )

  input_schema(
    properties: {
      param: { type: "string", description: "Description" }
    },
    required: ["param"]
  )

  def execute(param:)
    # Use: current_user, authorize, scope_*_by_user, call_tool
    # Return: plain text string (ApplicationTool wraps in Response)
  end
end
```
Tool auto-discovery: `McpController` loads all `*_tool.rb` files from this directory.

## Critical Rules
- All queries MUST use `.active` scope (soft delete awareness)
- Write operations MUST call `authorize(record, :action?)`
- Read operations MUST scope via `scope_*_by_user` methods
- Return plain text, not JSON — ApplicationTool wraps in `MCP::Tool::Response`
- Use `call_tool(GetTaskTool, task_id: id)` for cross-tool detail fetching after mutations
- Unauthenticated requests: `initialize`, `ping`, `tools/list` work without auth; `tools/call` requires Bearer token
