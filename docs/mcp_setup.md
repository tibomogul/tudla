# Model Context Protocol (MCP) Setup

This document describes how to set up and use the MCP integration for AI assistants to interact with the task management system.

## Quick Start

### 1. Start the Rails App

```bash
docker compose up
```

### 2. Generate an API Token

1. Visit http://localhost:3000
2. Log in with your account
3. Click your name in the topbar to go to your profile
4. Scroll to the "API Tokens" section under Security
5. Enter a name (e.g., "Claude Desktop") and click "Generate Token"
6. Copy the token from the modal (shown only once)

### 3. Configure Your AI Assistant

#### Claude Desktop

Edit `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "task-manager": {
      "transport": {
        "type": "sse",
        "url": "http://localhost:3000/mcp/sse",
        "headers": {
          "Authorization": "Bearer YOUR_TOKEN_HERE"
        }
      }
    }
  }
}
```

#### Cascade/Windsurf

Add to your MCP configuration:

```json
{
  "mcpServers": {
    "task-manager": {
      "transport": {
        "type": "sse",
        "url": "http://localhost:3000/mcp/sse",
        "headers": {
          "Authorization": "Bearer YOUR_TOKEN_HERE"
        }
      }
    }
  }
}
```

### 4. Test It

Restart your AI assistant, then try:
- "List my tasks"
- "Show me project 1"
- "Create a task called 'Test MCP integration'"
- "What changes have I made in the last 24 hours?"

## Architecture

| Component | Location | Description |
|-----------|----------|-------------|
| Configuration | `config/initializers/fast_mcp.rb` | MCP server setup |
| Tools | `app/tools/` | Individual tool classes |
| Resources | `app/resources/` | Resource classes (base only) |
| Authentication | `lib/mcp_auth_middleware.rb` | Bearer token middleware |
| Base Tool | `app/tools/application_tool.rb` | Shared tool logic |

### Endpoints

- **SSE Stream**: `http://localhost:3000/mcp/sse` (GET)
- **HTTP Messages**: `http://localhost:3000/mcp/messages` (POST)

## Available Tools

### Task Tools (6)

| Tool | Description | Read-Only |
|------|-------------|-----------|
| `ListTasksTool` | List/filter tasks by project, scope, user, state, today status | Yes |
| `GetTaskTool` | Get task details with state history and allowed transitions | Yes |
| `CreateTaskTool` | Create new task | No |
| `UpdateTaskTool` | Update task attributes | No |
| `TransitionTaskStateTool` | Change task state via state machine | No |
| `AssignTaskTool` | Assign task to user | No |

### Scope Tools (4)

| Tool | Description | Read-Only |
|------|-------------|-----------|
| `ListScopesTool` | List/filter scopes by project | Yes |
| `GetScopeTool` | Get scope details with tasks and completion percentage | Yes |
| `CreateScopeTool` | Create new scope | No |
| `UpdateScopeTool` | Update scope attributes | No |

### Project Tools (2)

| Tool | Description | Read-Only |
|------|-------------|-----------|
| `ListProjectsTool` | List all accessible projects | Yes |
| `GetProjectTool` | Get project details with scopes and tasks | Yes |

### Audit Tools (1)

| Tool | Description | Read-Only |
|------|-------------|-----------|
| `ListUserChangesTool` | List changes from PaperTrail audit log | Yes |

**Total: 13 tools** (all in `app/tools/`)

## Authentication

### How It Works

1. User generates API token via profile page
2. Token included in `Authorization: Bearer <token>` header
3. `McpAuthMiddleware` validates token and sets `Thread.current[:mcp_current_user]`
4. Tools access user via `current_user` method
5. All queries scoped to authenticated user's permissions via Pundit policies

### Token Management

- **Generate**: Profile page → Security → API Tokens
- **Revoke**: Click "Revoke" on token row
- **Delete**: Click "Delete" to soft-delete (archive)

### Token States

| State | Can Authenticate | Visible in List |
|-------|------------------|-----------------|
| Active | Yes | Yes |
| Revoked | No | Yes |
| Deleted | No | No |
| Expired | No | Yes |

## Creating New Tools

### Using Generator

```bash
docker compose exec rails bash -lc "rails generate fast_mcp:tool MyTool"
```

### Manual Creation

Create `app/tools/my_tool.rb`:

```ruby
class MyTool < ApplicationTool
  description "Description of what this tool does"

  annotations(
    title: "My Tool",
    read_only_hint: true  # false if it modifies data
  )

  arguments do
    required(:param1).filled(:string).description("Required parameter")
    optional(:param2).filled(:integer).description("Optional parameter")
  end

  def call(param1:, param2: nil)
    # Access current_user for the authenticated user
    # Use scope_tasks_by_user, scope_scopes_by_user, scope_projects_by_user
    # Use authorize(record, :action?) for Pundit authorization
    
    "Result string"
  end
end
```

### ApplicationTool Methods

| Method | Description |
|--------|-------------|
| `current_user` | Returns authenticated user (or nil) |
| `authorize(record, :action?)` | Pundit authorization check |
| `scope_tasks_by_user(tasks)` | Filter tasks by user permissions |
| `scope_scopes_by_user(scopes)` | Filter scopes by user permissions |
| `scope_projects_by_user(projects)` | Filter projects by user permissions |

## State Machine

Tasks use a Statesman state machine with these transitions:

```
new → in_progress
in_progress → in_review, blocked
in_review → done, blocked
blocked → in_progress
done → in_review (reopen)
```

`TransitionTaskStateTool` enforces these rules and returns an error for invalid transitions.

## Testing

### MCP Inspector

```bash
npx @modelcontextprotocol/inspector
# Select SSE transport
# URL: http://localhost:3000/mcp/sse
# Add Authorization header with your token
```

### Manual HTTP Test

```bash
curl -X POST http://localhost:3000/mcp/messages \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/list"
  }'
```

## Usage Examples

| Request | Tool Used |
|---------|-----------|
| "List all tasks in project 5" | ListTasksTool |
| "Create a task called 'Fix login bug'" | CreateTaskTool |
| "Show me details for task 42" | GetTaskTool |
| "Transition task 42 to in_progress" | TransitionTaskStateTool |
| "Assign task 15 to user 7" | AssignTaskTool |
| "List all scopes in project 2" | ListScopesTool |
| "What changes have I made today?" | ListUserChangesTool |
| "Show team 3's changes this week" | ListUserChangesTool (with team_id) |

## Troubleshooting

### Tools Not Appearing

1. Verify Rails app is running
2. Check `config/initializers/fast_mcp.rb` is loaded
3. Verify tools inherit from `ApplicationTool`
4. Check Rails logs for errors

### Authentication Errors

1. Verify token exists: Profile → API Tokens
2. Ensure token is active and not expired
3. Check header format: `Authorization: Bearer YOUR_TOKEN`
4. Check Rails logs for "MCP Auth" messages

### Permission Errors

Users only see resources they have access to:
- Tasks they're assigned to or in their projects
- Scopes in their projects
- Projects they're members of

Check `user_party_roles` table for project memberships.

### Invalid State Transition

Check allowed transitions:
```ruby
task.state_machine.allowed_transitions
```

## Security Considerations

- API tokens provide full access to the user's data
- Tokens should be kept secure and not shared
- Tokens can be revoked at any time
- Consider setting expiration dates on tokens
- All operations scoped to authenticated user's permissions
- State machine validations prevent invalid transitions

## Configuration Reference

### Server Configuration

`config/initializers/fast_mcp.rb`:

```ruby
FastMcp.mount_in_rails(
  Rails.application,
  name: Rails.application.class.module_parent_name.underscore.dasherize,
  version: "1.0.0",
  path_prefix: "/mcp",
  messages_route: "messages",
  sse_route: "sse",
  allowed_origins: ["localhost", /localhost:\d+/, "127.0.0.1", "[::1]"],
  localhost_only: false
) do |server|
  Rails.application.config.after_initialize do
    server.register_tools(*ApplicationTool.descendants)
    server.register_resources(*ApplicationResource.descendants)
  end
end
```

### Key Files

| File | Purpose |
|------|---------|
| `config/initializers/fast_mcp.rb` | MCP server configuration |
| `app/tools/application_tool.rb` | Base tool class with auth/scoping |
| `app/tools/concerns/mcp_formatters.rb` | Shared formatting helpers |
| `lib/mcp_auth_middleware.rb` | Token authentication middleware |
| `app/models/api_token.rb` | API token model |
| `app/controllers/api_tokens_controller.rb` | Token management |
