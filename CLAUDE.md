# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Primary Reference

`AGENTS.md` (root) is the authoritative reference for this codebase. It covers architecture, patterns, anti-patterns, and development commands in detail. Sub-knowledge bases:
- `app/tools/AGENTS.md` — MCP tool patterns and conventions
- `app/models/AGENTS.md` — Model concerns, associations, state machines
- `spec/AGENTS.md` — Test framework and factories

## Commands

All commands run inside the Docker container — never on the host.

```bash
# Start environment
docker compose up -d
docker compose exec rails bash -lc "bin/setup"                           # First-time DB setup
docker compose exec -d rails bash -lc "bin/dev"                          # Start dev server (background)
docker compose exec rails bash -lc "pkill -f foreman || true"            # Stop dev server

# Tests & quality
docker compose exec rails bash -lc "bundle exec rspec"                   # All specs
docker compose exec rails bash -lc "bundle exec rspec spec/models/task_spec.rb"  # Single spec
docker compose exec rails bash -lc "bundle exec rubocop"                 # Linter
docker compose exec rails bash -lc "bundle exec brakeman"                # Security scanner

# Database
docker compose exec rails bash -lc "bin/rails db:migrate"
docker compose exec rails bash -lc "bin/rails db:reset"
docker compose exec rails bash -lc "bin/rails console"
```

## Architecture Overview

Rails 8.1 task management app (Ruby 3.3.4) for teams using the Shape Up methodology. PostgreSQL 18, Hotwire (Turbo + Stimulus), Importmap, Tailwind CSS + DaisyUI 5.

**Multi-database**: primary (app data), queue (Solid Queue), cable (Solid Cable), cache (Solid Cache).

**Key gems**: Statesman (state machines), Pundit (authorization), Devise (auth + Google/Microsoft OAuth), PaperTrail (audit), `mcp` gem (MCP server), ViewComponent, Pagy.

### Domain Model

```
Organization → Team → Project → Scope → Task
```

`UserPartyRole` is a polymorphic join table assigning users roles (admin/member) to organizations, teams, or projects.

State machines (Statesman): `Task` (new → in_progress → in_review → done, with blocked) and `Project` (green/yellow/red risk state). **Never assign state directly** — use `state_machine.transition_to!(state, metadata)`.

### Critical Patterns

**Soft delete** — 10 models use `SoftDeletable` concern. There is NO `default_scope`. **Always use `.active`** on soft-deletable models in queries, controllers, policies, MCP tools, and views.

**Broadcasts** — 6 models broadcast via ActionCable. Always use named methods (not inline lambdas) with an ActionCable guard and error rescue. Broadcast-rendered partials must set `can_update: false` (no Devise context available).

**Estimate caching** — `EstimateCacheable` concern maintains denormalized estimate sums on `scopes` and `projects`. Never modify `cached_*_estimate` columns directly.

**Turbo Stream context** — Controllers accept `update_context` param (`"details"`, `"list_item"`, `"scope_list_item"`, `"dashboard"`) to select the correct partial for streaming responses. Always pass it via hidden fields in forms.

**MCP** — `McpController` authenticates via Bearer token, builds `MCP::Server` per request. Tools in `app/tools/` inherit from `ApplicationTool`. All MCP tool queries must use `.active` scope and Pundit authorization.

**Authorization** — Pundit policies in `app/policies/`. All policy scopes use `UserPartyRole` to filter accessible records through the org → team → project hierarchy.

**Timezone** — Organization-level timezone (default: `"Australia/Brisbane"`). All time display via `format_in_timezone`. Form inputs convert to/from org timezone, never browser timezone.
