# AGENTS.md

**Generated:** 2026-02-28 | **Commit:** 91047b7 | **Branch:** main

## Project Overview
Rails 8.1 task management app ("Tudla") for Shape Up methodology teams. PostgreSQL, Tailwind CSS + DaisyUI 5, Hotwire (Turbo + Stimulus), Docker.

## Tech Stack
- **Framework**: Ruby on Rails 8.1 (Ruby 3.3.4)
- **Database**: PostgreSQL 18 (multi-database: primary, queue, cable, cache)
- **Frontend**: Tailwind CSS + DaisyUI 5, Stimulus, Turbo, Importmap
- **State Machine**: Statesman ~> 13.0.0
- **Auth**: Devise (email/password + Google/Microsoft OAuth), Pundit (authorization)
- **Audit**: PaperTrail ~> 17.0 (HashDiff adapter)
- **Background Jobs**: Solid Queue
- **Caching**: Solid Cache
- **WebSockets**: Solid Cable (async dev, solid_cable production)
- **Markdown**: Commonmarker ~> 2.5 + Marksmith ~> 0.4.7
- **Components**: ViewComponent
- **Pagination**: Pagy
- **MCP**: Official `mcp` gem (Streamable HTTP)
- **Containerization**: Docker Compose

## Sub-Knowledge Bases
- `app/tools/AGENTS.md` — MCP tool patterns, ApplicationTool conventions, adding new tools
- `app/models/AGENTS.md` — Model layer: concerns, associations, delegated types, state machines
- `spec/AGENTS.md` — Test framework, factories, running specs

## Development Setup
```bash
docker compose up -d
docker compose exec rails bash -l
$ bin/setup              # Creates all DBs, migrates, seeds
$ bin/dev                # Starts web + CSS + jobs + mailcatcher
# App: http://localhost:3000 | Mail: http://localhost:1080
```

## Project Structure
```
app/
├── components/      # ViewComponent classes (2)
├── controllers/     # Rails controllers (17 + concerns/)
├── helpers/         # View helpers (8)
├── javascript/      # Stimulus controllers (15)
├── jobs/            # Solid Queue jobs (2)
├── models/          # ActiveRecord models (25 + concerns/) → see app/models/AGENTS.md
├── policies/        # Pundit authorization (10)
├── services/        # Business logic POROs (3)
├── state_machines/  # Statesman definitions (2)
├── tools/           # MCP tools (13 + concerns/) → see app/tools/AGENTS.md
└── views/           # ERB templates (19 dirs, 116 files)

config/
├── routes.rb        # Resources + MCP + OAuth discovery
├── database.yml     # Multi-database (primary, queue, cable, cache)
├── recurring.yml    # Solid Queue recurring jobs
└── initializers/    # Devise, Statesman, PaperTrail, Slack, StrongMigrations (13)

db/                  # 41 migrations + schema files
docs/                # 19 implementation + operational docs
lib/                 # CustomFailure (Devise) + rake tasks
spec/                # RSpec specs → see spec/AGENTS.md
```

## Key Files
- `Gemfile` — Dependencies (Rails 8.1, Statesman, Pundit, Devise, PaperTrail, mcp)
- `compose.yml` — Docker services (Rails + PostgreSQL 18)
- `Dockerfile` — Multi-stage build with configurable UID/GID, SSH forwarding
- `Procfile.dev` — 4 processes: web, css (tailwind), que (solid_queue), mai (mailcatcher)
- `config/routes.rb` — All resources + MCP endpoints + OAuth discovery

## Database Schema

### Multi-Database Configuration
- **Primary DB** (`task_manager_development`): Main application data
- **Queue DB** (`task_manager_development_queue`): Solid Queue (11 tables)
- **Cable DB** (`task_manager_development_cable`): Solid Cable (WebSocket storage)
- **Cache DB** (`task_manager_production_cache`): Solid Cache (production only)

**Setup**: `bin/setup` automatically creates and loads schemas for all databases

### Key Tables (Primary DB)
- **tasks**: responsible_user_id, project_id, scope_id, state, estimates, positions
- **users**: Devise authentication (username, preferred_name, email, OAuth)
- **projects**: team_id, risk_state, cached estimates
- **scopes**: project_id, cached estimates, positions
- **teams**: organization_id
- **organizations**: timezone (default: "Australia/Brisbane")
- **task_transitions / project_risk_transitions**: Statesman audit trail (JSONB metadata)
- **user_party_roles**: Polymorphic role assignments (user → organization/team/project)
- **notes / links / attachments**: Polymorphic via delegated_type containers
- **reports / report_requirements**: Reporting with IceCube scheduling
- **subscriptions / events / notifications**: Subscription/notification system
- **api_tokens**: MCP Bearer token auth (dual-state: active + deleted_at)

## Key Features

### Task Management
- **State Machine**: new → in_progress → in_review → done (with blocked state)
- **Guard**: Moving to `in_progress` requires `responsible_user`, `unassisted_estimate`, `ai_assisted_estimate`
- **Responsible User Assignment**: Searchable dropdown via `assignable_users` method
- **Dashboard**: Today list, backlog, completed today — drag-and-drop reordering (SortableJS)
- **Time Tracking**: `time_in_current_state` calculated from transitions

### State Machine (Statesman Gem)

#### Task States & Transitions
```
new → in_progress → in_review → done
       ↘ blocked ↗            ↘ blocked ↗
done → in_review (reopen)
```

#### Project Risk States
```
green ↔ yellow ↔ red (all transitions valid)
```

#### Key Methods
- `task.current_state` / `task.state_machine.allowed_transitions`
- `task.state_machine.can_transition_to?(state)` / `transition_to!(state, metadata)`
- `Task.in_state(:new)` / `Task.not_in_state(:done)` (Statesman query adapter)
- Metadata stores `user_id`: `transition_to!(:in_progress, user_id: current_user.id)`

#### State Display Colors (DaisyUI)
- new: badge-primary / btn-neutral
- in_progress: badge-info / btn-info
- in_review: badge-warning / btn-warning
- done: badge-success / btn-success
- blocked: badge-error / btn-error

### Authorization
- **Pundit policies** for all resources (10 policies with Scope inner classes)
- **Hierarchy**: Organization → Team → Project
- **UserPartyRole**: Polymorphic join (user → org/team/project) with role (admin/member)
- **Context-safe**: Handles Devise/Warden unavailability in broadcast contexts
- **Project creation**: Org admins → any team; Team admins → their team only

### Delegated Types (Polymorphic Composition)
5 containers using Rails `delegated_type`:
- **Notable** → Note: Project, Scope, Task, Team, Organization
- **Linkable** → Link: Project, Scope, Task, Team, Organization
- **Attachable** → Attachment (Active Storage): Project, Scope, Task, Team, Organization
- **Subscribable** → Subscription: Project, Scope, Task
- **Reportable** → Report: Project, Team

### Services (POROs)
- **SlackService** — Posts reports to Slack (webhook or Bot token), timezone-aware formatting
- **TaskFlowAnalyzer** — State duration analytics, per-user cycle times from TaskTransition data
- **ReportRequirementReminderScheduler** — Schedules reminder jobs via IceCube + Solid Queue

### ViewComponents
- **PaginatedListComponent** — Reusable paginated list with search filtering (Stimulus `list-filter`)
- **AttachmentPreviewCarouselComponent** — Image/PDF/video/audio carousel with zoom/pan

### Background Jobs
- **PostReportToSlackJob** — Async Slack posting via SlackService
- **ReportRequirementReminderJob** — Report deadline reminders

## Development Patterns

### Turbo Stream Context Management
- Controllers accept `update_context` parameter to determine response format
- Contexts: `"details"` (default), `"list_item"`, `"scope_list_item"`, `"dashboard"`
- Passed via hidden fields in forms, extracted in controllers with fallback
- Prevents incorrect partial rendering (e.g., details partial replacing list item)

### Reusable Partials
- **`tasks/_responsible_user_selector.html.erb`**: Accepts `can_update`, `show_label`, `button_class`, `update_context`
- **`shared/_task_list_item.html.erb`**: Used in dashboard, scope views, and broadcasts
- **`shared/_notes_list.html.erb`**, **`_links_list.html.erb`**, **`_attachments_list.html.erb`**: Polymorphic attachment UI

### Stimulus Controllers
- **user_select** — Searchable dropdown with real-time filtering
- **sortable** / **sortable_scope** — Drag-and-drop reordering via SortableJS
- **list_filter** — Real-time search with 300ms debounce
- **hillchart** — Shape Up hill chart visualization
- **flash** — Auto-dismiss messages after 5 seconds
- Auto-loaded from `app/javascript/controllers/` via `eagerLoadControllersFrom`

### Broadcast Pattern (Console/Runner Safe)
All 6 broadcast models use **named methods with ActionCable guards**:
```ruby
after_commit :broadcast_method_name, if: :persisted?

private
def broadcast_method_name
  return unless ActionCable.server.pubsub.respond_to?(:broadcast)
  broadcast_replace_to ...
rescue => e
  Rails.logger.error("Failed to broadcast: #{e.message}")
end
```

**Models with safe broadcasts (6 total)**:
- `Task` → broadcast_task_update (replace to "tasks" stream)
- `Project` → broadcast_project_update (replace to "projects" stream)
- `TaskTransition` → broadcast_transition (append to "task_{id}_history")
- `ProjectRiskTransition` → broadcast_transition (append to "project_{id}_risk_history")
- `Note` → broadcast_note_update (replace to "{type}_{id}_notes")
- `Link` → broadcast_link_update (replace to "{type}_{id}_links")

**Key Points**:
- ✅ Named methods (inline lambdas fail in console)
- ✅ ActionCable guard prevents errors in non-web contexts
- ✅ Partials in broadcasts set `can_update: false` (no Devise context)
- ✅ Avoid policy checks in broadcast-rendered partials

### Soft Delete Implementation
- **10 models**: Project, Scope, Task, Note, Link, Attachment, Organization, Team, Report, ApiToken
- **Concern**: `SoftDeletable` (app/models/concerns/soft_deletable.rb)
- **NO default_scope** — Must explicitly use `.active` in ALL queries
- **Scopes**: `active` (not deleted), `with_deleted`, `only_deleted`
- **Methods**: `soft_delete`, `restore`, `deleted?`
- **Critical**: Controllers, policies, MCP tools, views — ALL must use `.active`
- **ApiToken special**: Dual-state (`active` column + `deleted_at`), `active` scope checks both + expiry

### Timezone Handling
- **Organization-level**: `timezone` field (default: "Australia/Brisbane")
- **Hierarchy**: Task → Project → Team → Organization
- **Display**: All times via `format_in_timezone` method
- **Editing**: Form inputs convert to/from organization timezone (NOT browser timezone)
- **Documentation**: See `docs/timezone_handling.md`

### Estimate Rollup Caching
- **Concern**: `EstimateCacheable` (included in Task)
- **Cached on**: `scopes` and `projects` tables
- **Columns**: `cached_unassisted_estimate`, `cached_ai_assisted_estimate`, `cached_actual_manhours`
- **Triggers**: Task create/update/destroy/restore; handles reassignment between parents
- **Backfill**: `bin/rails estimate_cache:backfill`

### PaperTrail Audit
- **6 models tracked**: Task, Scope, Project, Note, Link, Attachment
- **Skipped columns**: Task skips positions/in_today; Scope skips position
- **MCP access**: `ListUserChangesTool` queries versions with time range and team filtering
- **Adapter**: HashDiff for efficient object_changes storage

## Model Context Protocol (MCP) Integration

### Overview
MCP integration enables AI assistants to interact with Tudla via 13 standardized tools using the official `mcp` gem.

### Architecture
- **Endpoint**: `POST /mcp` (Streamable HTTP)
- **Auth**: Bearer token via `Authorization: Bearer <token>` header
- **Controller**: `McpController` builds `MCP::Server` per request with user context
- **Tools**: 13 total in `app/tools/` — see `app/tools/AGENTS.md` for details
- **Discovery**: `/.well-known/mcp` + OAuth metadata endpoints for rmcp compatibility
- **Token management**: Users generate via Profile → Security → API Tokens

### Configuration Example
```json
{
  "mcpServers": {
    "task-manager": {
      "type": "http",
      "url": "http://localhost:3000/mcp",
      "headers": {
        "Authorization": "Bearer YOUR_TOKEN_HERE"
      }
    }
  }
}
```

### Tool Pattern
Tools inherit from `ApplicationTool < MCP::Tool`. Each defines `description`, `annotations`, `input_schema`, and `def execute(**args)`. See `app/tools/AGENTS.md` for full conventions.

## Testing
- **Framework**: RSpec 8.0 with rspec-rails, FactoryBot, SimpleCov
- **Specs**: 41 across models, requests, routing, helpers, components, tools
- **Run**: `docker compose exec rails bundle exec rspec`
- **Details**: See `spec/AGENTS.md`

## Development Commands
```bash
# Server
docker compose up -d && docker compose exec rails bash -l
bin/dev                                    # Start all processes
bin/setup                                  # Reset + setup all DBs

# Tests & Quality
bundle exec rspec                          # All specs
bundle exec rubocop                        # Linter (Rails Omakase)
bundle exec brakeman                       # Security scanner

# Database
bin/rails db:migrate                       # Run migrations
bin/rails db:reset                         # Drop + create + migrate + seed
bin/rails console                          # Rails console

# Maintenance
bin/rails estimate_cache:backfill          # Recalculate cached estimates
bin/rails report_reminders:schedule        # Schedule reminder jobs
bin/backup                                 # Backup DBs + storage
bin/restore                                # Restore from backup
```

## Anti-Patterns (NEVER Do)
- Query without `.active` scope on soft-deletable models
- Use `default_scope` for soft delete (conflicts with Statesman + Rails 8 insert_all)
- Inline lambda broadcasts (fail in console; use named methods with ActionCable guard)
- Policy checks in broadcast-rendered partials (no Devise context available)
- Skip `update_context` in Turbo Stream forms (causes wrong partial rendering)
- Hard-code timezone (always use organization timezone via `format_in_timezone`)
- Modify cached estimate columns directly (use EstimateCacheable callbacks)
- Direct state assignment on Task/Project (use `state_machine.transition_to!`)

## Development Notes
- Tailwind CSS + DaisyUI 5 for styling (see `docs/daisyui.md` for component reference)
- Rubocop with Rails Omakase styling
- Brakeman for security analysis
- Strong Migrations enabled (lock_timeout: 10s, statement_timeout: 1h)
- Docker with volume mounting (configurable UID/GID for permissions)
- ActionView::RecordIdentifier included in controllers for `dom_id` helper
- Custom Devise failure handler (`lib/custom_failure.rb`) redirects to root_path
- String-based class name comparison in policies (avoids Rails class reloading issues)
