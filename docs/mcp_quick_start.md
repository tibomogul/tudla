# MCP Quick Start Guide

Get up and running with MCP in 5 minutes.

## Step 1: Start Your Rails App

```bash
docker compose up
```

## Step 2: Generate an API Token

1. Visit http://localhost:3000
2. Log in with your account
3. Click your name in the topbar to go to your profile
4. Scroll to the "API Tokens" section
5. Enter a name (e.g., "Claude Desktop") and click "Generate Token"
6. Copy the token from the modal that appears

## Step 3: Configure Your AI Assistant

### For Claude Desktop

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

### For Cascade

Add to your Cascade MCP config:

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

## Step 4: Test It

Restart your AI assistant, then try:

- "List my tasks"
- "Show me project 1"
- "Create a task called 'Test MCP integration'"
- "What changes have I made in the last 24 hours?"

## What's Available?

**13 Tools:**
- List/Get/Create/Update/Transition/Assign Tasks
- List/Get/Create/Update Scopes  
- List/Get Projects
- List User Changes (audit log)

All scoped to your permissions automatically!

## Need Help?

- Full docs: `docs/mcp_setup.md`
- Manage tokens: Profile page → Security → API Tokens
- View tools: `app/tools/` directory
- Config: `config/initializers/fast_mcp.rb`
