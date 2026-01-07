# MCP Implementation Migration

This document describes the migration from the custom monolithic MCP server to the Rails-integrated fast-mcp implementation.

## What Changed

### Before (Custom Implementation)
- ❌ Monolithic `mcp/task_manager_server.rb` file (1300+ lines)
- ❌ Custom HTTP server (`mcp/http_server.rb`)
- ❌ Custom executable (`bin/mcp-server`)
- ❌ Manual tool registration
- ❌ Custom authentication handling
- ❌ Separate server process
- ❌ Required sinatra and rackup gems

### After (Rails-based fast-mcp)
- ✅ 12 individual tool classes in `app/tools/`
- ✅ Built-in HTTP support via Rack middleware
- ✅ Automatic tool discovery
- ✅ Rails-integrated authentication
- ✅ Runs as part of Rails app
- ✅ Follows Rails conventions
- ✅ Uses fast-mcp gem only

## File Changes

### Deleted Files
- `mcp/task_manager_server.rb` (old monolithic server)
- `mcp/http_server.rb` (custom HTTP wrapper)
- `bin/mcp-server` (custom executable)
- `mcp/README.md` (old docs)
- `mcp/claude_desktop_config.example.json` (old config)
- `mcp/cascade_config.example.json` (old config)
- `mcp/docker_config.example.json` (old config)

### New Files

#### Configuration
- `config/initializers/fast_mcp.rb` - MCP configuration

#### Tools (app/tools/)
- `application_tool.rb` - Base class with auth and scoping
- `list_tasks_tool.rb` - List/filter tasks
- `get_task_tool.rb` - Get task details
- `create_task_tool.rb` - Create new task
- `update_task_tool.rb` - Update task
- `transition_task_state_tool.rb` - Change task state
- `assign_task_tool.rb` - Assign task to user
- `list_scopes_tool.rb` - List/filter scopes
- `get_scope_tool.rb` - Get scope details
- `create_scope_tool.rb` - Create new scope
- `update_scope_tool.rb` - Update scope
- `list_projects_tool.rb` - List projects
- `get_project_tool.rb` - Get project details

#### Authentication
- `app/models/api_token.rb` - API token model
- `app/controllers/api_tokens_controller.rb` - Token management
- `app/views/api_tokens/index.html.erb` - Token management UI
- `db/migrate/20251101083306_create_api_tokens.rb` - Token table

#### Documentation
- `docs/mcp_setup.md` - Complete setup guide
- `docs/mcp_quick_start.md` - Quick start guide
- `docs/mcp_migration.md` - This file

### Modified Files
- `Gemfile` - Removed sinatra, rackup, duplicate puma
- `config/routes.rb` - Added api_tokens routes
- `app/models/user.rb` - Added api_tokens association
- `AGENTS.md` - Updated MCP section

## Configuration Changes

### Old Configuration (STDIO)
```json
{
  "mcpServers": {
    "task-manager": {
      "command": "/path/to/bin/mcp-server",
      "env": {
        "RAILS_ENV": "development"
      }
    }
  }
}
```

### New Configuration (HTTP/SSE)
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

## Authentication Changes

### Before
- No authentication (if using STDIO)
- Or custom request-level authentication (if using HTTP server)
- User context passed as parameter

### After
- API token-based authentication
- Token management UI at `/api_tokens`
- User automatically determined from token
- All queries scoped to authenticated user

## Migration Steps for Users

1. **Update Configuration**
   - Replace STDIO config with SSE config
   - Generate API token at `/api_tokens`
   - Add token to config

2. **Restart Rails App**
   ```bash
   docker compose restart
   ```

3. **Restart AI Assistant**
   - Restart Claude Desktop, Cascade, etc.

4. **Test**
   - Try: "List my tasks"
   - Verify tools appear and work

## Benefits

1. **Maintainability**
   - Individual tool classes are easier to understand and modify
   - Each tool has single responsibility
   - Standard Rails patterns

2. **Discoverability**
   - Tools automatically discovered from `app/tools/`
   - No manual registration needed
   - Easy to add new tools

3. **Integration**
   - Runs as part of Rails app
   - No separate process to manage
   - Access to full Rails stack

4. **Security**
   - Token-based authentication
   - Per-user access control
   - Token revocation support

5. **Testing**
   - Individual tools can be tested in isolation
   - Standard Rails testing patterns apply

## Troubleshooting

### Tools not working?
1. Verify Rails app is running
2. Check `/api_tokens` for valid token
3. Verify token in Authorization header
4. Check Rails logs for errors

### Permission errors?
- Ensure user has project memberships
- Check `user_party_roles` table
- Tools are scoped to user's accessible resources

## Future Enhancements

Potential improvements to consider:
- Add resource classes in `app/resources/`
- Add more granular permissions
- Add rate limiting for API tokens
- Add token usage analytics
- Add webhook notifications
- Add batch operation tools
