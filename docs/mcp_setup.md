# Model Context Protocol (MCP) Setup

This document describes how to set up and use the Task Manager MCP integration using the fast-mcp gem with Rails.

## Overview

The Task Manager uses fast-mcp's Rails integration to provide AI assistants with tools to interact with your task management system. The implementation follows Rails conventions with individual tool classes and automatic discovery.

## Architecture

- **Framework**: fast-mcp gem with Rails integration
- **Tools Location**: `app/tools/` directory
- **Resources Location**: `app/resources/` directory
- **Configuration**: `config/initializers/fast_mcp.rb`
- **Transport**: HTTP via Rack middleware (SSE and JSON-RPC)
- **Authentication**: Bearer token via Authorization header

## Available Tools

### Task Tools
- **ListTasksTool** - List and filter tasks by project, scope, user, state, today status
- **GetTaskTool** - Get task details including state history and allowed transitions
- **CreateTaskTool** - Create new task with all attributes
- **UpdateTaskTool** - Update task attributes
- **TransitionTaskStateTool** - Change task state via state machine (validates transitions)
- **AssignTaskTool** - Assign task to user

### Scope Tools
- **ListScopesTool** - List and filter scopes by project
- **GetScopeTool** - Get scope details with tasks and completion percentage
- **CreateScopeTool** - Create new scope in project
- **UpdateScopeTool** - Update scope attributes

### Project Tools
- **ListProjectsTool** - List all projects
- **GetProjectTool** - Get project details with scopes and tasks

### Audit Tools
- **ListUserChangesTool** - List changes made by current user from PaperTrail audit log (defaults to last 24 hours)

## Authentication

The MCP server uses API tokens for authentication. Each user can generate their own tokens.

### Generating API Tokens

1. Log in to the Task Manager web application
2. Navigate to your profile page (click your name in the topbar)
3. Scroll to the "API Tokens" section under Security
4. Enter a token name and click "Generate Token"
5. Copy the token from the modal (it will only be shown once)

### Using Tokens

Include the token in the Authorization header:

```
Authorization: Bearer your-token-here
```

When authenticated, users will only see tasks, scopes, and projects they have access to based on their project memberships.

## Configuration

### Server Configuration

The MCP server is configured in `config/initializers/fast_mcp.rb`:

```ruby
FastMcp.mount_in_rails(
  Rails.application,
  name: 'task-manager',
  version: '1.0.0',
  path_prefix: '/mcp',
  messages_route: 'messages',
  sse_route: 'sse'
)
```

### Endpoints

- **HTTP Messages**: `http://localhost:3000/mcp/messages` (POST)
- **SSE Stream**: `http://localhost:3000/mcp/sse` (GET)

## Client Configuration

### For Claude Desktop

Add to your Claude Desktop config (`~/Library/Application Support/Claude/claude_desktop_config.json` on macOS):

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

### For Cascade/Windsurf

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

### For Docker Deployment

When using Docker, update the URL to point to your Docker host:

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

## Development

### Starting the Server

The MCP server runs as part of your Rails application:

```bash
# Development
docker compose up

# Access at http://localhost:3000
# MCP endpoints at http://localhost:3000/mcp/
```

### Creating New Tools

Generate a new tool:

```bash
docker compose exec rails bash -lc "rails generate fast_mcp:tool MyTool"
```

Or create manually in `app/tools/`:

```ruby
# app/tools/my_tool.rb
class MyTool < ApplicationTool
  description "Description of what this tool does"

  annotations(
    title: "My Tool",
    read_only_hint: true  # or false if it modifies data
  )

  arguments do
    required(:param1).filled(:string).description("Parameter description")
    optional(:param2).filled(:integer).description("Optional parameter")
  end

  def call(param1:, param2: nil)
    # Your implementation
    # Access current_user for scoping
    # Use scope_tasks_by_user, scope_scopes_by_user, scope_projects_by_user
    
    "Result"
  end
end
```

### Authentication in Tools

All tools inherit from `ApplicationTool` which provides:

- `current_user` - Returns the authenticated user (or nil)
- `scope_tasks_by_user(tasks)` - Scope tasks by user permissions
- `scope_scopes_by_user(scopes)` - Scope scopes by user permissions
- `scope_projects_by_user(projects)` - Scope projects by user permissions

## Testing

### Using MCP Inspector

Test your tools with the official MCP inspector:

```bash
# Test with SSE transport
npx @modelcontextprotocol/inspector
# Then select SSE and enter: http://localhost:3000/mcp/sse
# Add your token in the headers section
```

### Manual Testing

You can also test the HTTP endpoint directly:

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

Once configured, your AI assistant will have access to these tools:

- "List all tasks in project 5"
- "Create a new task called 'Fix login bug' in project 3"
- "Show me details for task 42"
- "Transition task 42 to in_progress"
- "Assign task 15 to user 7"
- "List all scopes in project 2"
- "Create a scope called 'User Authentication' in project 1"
- "What's the status of scope 8?"
- "What changes have I made in the last 24 hours?"
- "Show me all my changes from 2025-11-01 to 2025-11-03"

## State Machine

Tasks use a Statesman state machine with these transitions:

- **new** → in_progress
- **in_progress** → in_review, blocked
- **in_review** → done, blocked
- **blocked** → in_progress
- **done** → in_review (for reopening)

The `TransitionTaskStateTool` enforces these rules and returns an error for invalid transitions.

## Troubleshooting

### Tools not appearing

1. Restart your Rails application
2. Check `config/initializers/fast_mcp.rb` is loaded
3. Verify tools inherit from `ApplicationTool`
4. Check Rails logs for errors

### Authentication errors

1. Verify token is valid: Check profile page → API Tokens section
2. Ensure token is active and not expired
3. Check Authorization header format: `Bearer YOUR_TOKEN`
4. Verify token belongs to a user with project access

### Permission errors

Users can only see resources they have access to:
- Tasks they're assigned to or in their projects
- Scopes in their projects
- Projects they're members of

Check `user_party_roles` table for project memberships.

## Security Considerations

- API tokens provide full access to the user's data
- Tokens should be kept secure and not shared
- Tokens can be revoked at any time via `/api_tokens`
- Consider setting expiration dates on tokens
- All operations are scoped to the authenticated user's permissions
- State machine validations prevent invalid transitions

## Comparison with Previous Implementation

The previous implementation used a monolithic server file. The new Rails-based approach:

✅ **Benefits:**
- Individual tool classes (Rails convention)
- Automatic tool discovery
- Built-in HTTP support via Rack middleware
- No custom server process needed
- Integrates seamlessly with Rails app
- Easier to test and maintain
- Proper error handling via exceptions

📝 **Migration Notes:**
- Old `mcp/task_manager_server.rb` removed
- Old `bin/mcp-server` removed
- Old custom HTTP server removed
- Tools now in `app/tools/` directory
- Authentication via API tokens instead of request-level auth
