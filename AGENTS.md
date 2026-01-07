# AGENTS.md

## Project Overview
Rails 8.0.3 task management application with PostgreSQL database, Tailwind CSS, and Docker containerization.

## Tech Stack
- **Framework**: Ruby on Rails 8.0.3
- **Ruby Version**: 3.3.4
- **Database**: PostgreSQL
- **Frontend**: Tailwind CSS, Stimulus, Turbo, Importmap
- **State Machine**: Statesman gem ~> 13.0.0
- **Background Jobs**: Solid Queue
- **Caching**: Solid Cache
- **WebSockets**: Solid Cable
- **Containerization**: Docker Compose
- **MCP Integration**: fast-mcp gem ~> 1.0 for Model Context Protocol

## Development Setup
```bash
# Database setup
docker compose exec rails bin/setup

# Start development server
docker compose up

# Access application at http://localhost:3000
# Mailcatcher at http://localhost:1080
```

## Project Structure
```
app/
├── controllers/     # Rails controllers
├── models/         # ActiveRecord models  
├── views/          # ERB templates
├── assets/         # CSS, images
└── javascript/     # Stimulus controllers

config/
├── routes.rb       # URL routing
├── database.yml    # DB configuration
└── environments/   # Environment configs

db/
├── schema.rb       # Database schema
└── seeds.rb        # Seed data
```

## Key Files
- `Gemfile` - Ruby dependencies
- `compose.yml` - Docker services (Rails app + PostgreSQL)
- `Dockerfile` - Multi-stage container build
- `Procfile.dev` - Development processes
- `config/routes.rb` - Currently minimal, only health check

## Database Schema

### Multi-Database Configuration
- **Primary DB** (`task_manager_development`): Main application data
- **Queue DB** (`task_manager_development_queue`): Solid Queue tables (11 tables for background jobs)
- **Cable DB** (`task_manager_development_cable`): Solid Cable tables (WebSocket message storage)
- **Cache DB** (`task_manager_production_cache`): Solid Cache (production only)

**Setup**: `bin/setup` automatically creates and loads schemas for all databases

### Key Tables (Primary DB)
- **tasks**: Main task records with responsible_user_id, project_id, scope_id, state tracking
- **users**: User accounts with Devise authentication (username, preferred_name, email)
- **projects**: Project organization with team associations
- **teams**: Team structure within organizations
- **task_transitions**: State machine transitions for tasks
- **project_risk_transitions**: Risk state transitions for projects
- **user_party_roles**: Polymorphic role assignments (user → organization/team/project)

## Key Features

### Task Management
- **Responsible User Assignment**: 
  - Searchable dropdown for assigning users to tasks
  - Filters by username then preferred_name
  - Uses `assignable_users` method (task owner, project team members, project users)
  - Policy-based permissions via Pundit TaskPolicy
  - Context-aware updates (details view vs list item view)

### State Machine (Statesman Gem)
Uses Statesman gem ~> 13.0.0 for robust state management with full audit trail.

#### State Machine Definition (`app/state_machines/task_state_machine.rb`)
```ruby
class TaskStateMachine
  include Statesman::Machine
  
  # States
  state :new, initial: true
  state :in_progress
  state :in_review
  state :done
  state :blocked
  
  # Valid Transitions
  transition from: :new,         to: [:in_progress]
  transition from: :in_progress, to: [:in_review, :blocked]
  transition from: :in_review,   to: [:done, :blocked]
  transition from: :blocked,     to: [:in_progress]
  transition from: :done,        to: [:in_review]  # for reopen
  
  # Guards
  guard_transition(to: :in_progress) do |task, transition|
    task.responsible_user.present?  # requires assigned user
  end
end
```

#### Task Model Integration (`app/models/task.rb`)
- **Statesman Adapter**: Includes `Statesman::Adapters::ActiveRecordQueries` for efficient querying
  - Provides class-level query methods: `Task.in_state(:new)`, `Task.not_in_state(:done)`
  - Used in controllers and MCP tools for filtering tasks by state
- **Association**: `has_many :task_transitions` (autosave: false)
- **State Machine Instance**: `state_machine` method returns `TaskStateMachine` instance
- **Current State**: Delegates `current_state` to state machine
- **Time Tracking**: `time_in_current_state` calculates duration in current state
- **Broadcasts**: After commit callback broadcasts task updates via Turbo Streams

#### Project Risk State Machine (`app/models/project.rb`)
- **Statesman Adapter**: Includes `Statesman::Adapters::ActiveRecordQueries` for efficient querying
  - Provides class-level query methods: `Project.in_state(:green)`, `Project.not_in_state(:red)`
  - Used in controllers and MCP tools for filtering projects by risk state
- **Association**: `has_many :project_risk_transitions` (autosave: false)
- **State Machine Instance**: `risk_state_machine` method returns `ProjectRiskStateMachine` instance
- **Current State**: `risk_current_state` method with fallback to `risk_state` column
- **Time Tracking**: `time_in_current_risk_state` calculates duration in current risk state
- **Broadcasts**: After commit callback using named method `broadcast_project_update` with ActionCable guard

#### TaskTransition Model (`app/models/task_transition.rb`)
- **Belongs to**: task (inverse_of: :task_transitions)
- **Metadata**: JSONB field stores transition context (e.g., `user_id`)
- **Audit Trail**: Tracks all state changes with timestamps
- **Most Recent**: Boolean flag marks current state (unique index on task_id + most_recent)
- **Sort Key**: Integer for ordering transitions
- **Broadcasts**: After commit callback appends transition to history timeline
- **Cleanup**: After destroy callback updates most_recent flag on remaining transitions

#### Database Schema (`task_transitions` table)
```ruby
t.string :to_state, null: false
t.jsonb :metadata, default: {}      # Stores user_id, etc.
t.integer :sort_key, null: false    # Ordering
t.bigint :task_id, null: false      # FK to tasks
t.boolean :most_recent, null: false # Current state marker
t.timestamps

# Indexes
- (task_id, sort_key) UNIQUE
- (task_id, most_recent) UNIQUE WHERE most_recent
- metadata GIN index for JSONB queries
```

#### State Transitions in Controllers (`tasks_controller.rb#update_state`)
```ruby
# Route: PATCH /tasks/:id/update_state
def update_state
  new_state = params[:state].to_sym
  @update_context = params[:update_context] || "dashboard"
  
  if @task.state_machine.can_transition_to?(new_state)
    @task.state_machine.transition_to!(new_state, user_id: current_user.id)
    # Context-aware response
  end
end
```

#### Context-Aware Rendering
- **Dashboard context**: Updates all lists (today, backlog, completed) + counts
- **Details context**: Updates only task details view
- **View helpers**: `badge_color(state)` and `button_color(state)` for DaisyUI styling
- **Allowed transitions**: Use `task.state_machine.allowed_transitions` to show available actions
- **User attribution**: Stores `user_id` in transition metadata for audit trail

#### State Display Colors (DaisyUI classes)
- **new**: badge-primary / btn-neutral
- **in_progress**: badge-info / btn-info
- **in_review**: badge-warning / btn-warning
- **done**: badge-success / btn-success
- **blocked**: badge-error / btn-error

#### Key Methods
- `task.current_state` - Returns current state symbol
- `task.state_machine.can_transition_to?(state)` - Check if transition is valid
- `task.state_machine.transition_to!(state, metadata)` - Perform transition
- `task.state_machine.allowed_transitions` - List of valid next states
- `task.time_in_current_state` - Duration in current state (Time or nil)
- `task.task_transitions.order(:sort_key)` - All transitions chronologically

#### History View
- Route: GET /tasks/:id/history
- Filterable by user_id and time period (7/30/90 days or all)
- Uses JSONB query: `WHERE metadata ->> 'user_id' = ?`
- Broadcasts new transitions to `task_#{task.id}_history` stream

### Authorization
- Pundit policies for all resources (TaskPolicy, ProjectPolicy, etc.)
- Role-based access control via user_party_roles
- Hierarchy: Organization → Team → Project
- Context-sensitive permission checks (handles Devise/Warden unavailability in broadcasts)

## Development Patterns

### Turbo Stream Context Management
- Controllers accept `update_context` parameter to determine response format
- Example contexts: "details", "list_item", "dashboard"
- Prevents incorrect partial rendering (e.g., details replacing list items)

### Reusable Partials
- **`tasks/_responsible_user_selector.html.erb`**: 
  - Accepts `can_update`, `show_label`, `button_class`, `update_context` parameters
  - Used in details, list items, and broadcast contexts

### Stimulus Controllers
- **`user_select_controller.js`**: Searchable dropdown with real-time filtering
- Auto-loaded from `app/javascript/controllers/`
- Handles form submission via Turbo

### Broadcast Pattern (Console/Runner Safe)
All models with broadcasts use **named methods with ActionCable guards** to work in all contexts (web, console, runner, tests):

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
- `Project` - broadcast_project_update
- `Task` - broadcast_task_update
- `ProjectRiskTransition` - broadcast_transition
- `TaskTransition` - broadcast_transition
- `Link` - broadcast_link_update
- `Note` - broadcast_note_update

**Key Points**:
- ✅ Named methods instead of inline lambdas (inline lambdas fail in console)
- ✅ ActionCable availability check prevents errors in non-web contexts
- ✅ `if: :persisted?` guard ensures record is saved
- ✅ Error handling with logging for debugging
- Model callbacks (`after_commit`) render without Devise/Warden context
- Partials used in broadcasts should set `can_update: false`
- Avoid policy checks in broadcast-rendered partials

### Timezone Handling
- **Organization Timezone**: Each organization has a `timezone` field (default: "Australia/Brisbane")
- **Model Methods**: Task, Project, and Report models include `timezone` and `format_in_timezone` methods
- **Display**: All time display uses organization timezone via `format_in_timezone`
- **Editing**: Form inputs convert to/from organization timezone (not user's browser timezone)
- **Controllers**: ReportsController parses datetime inputs in organization timezone
- **SlackService**: Formats dates in organization timezone when posting reports
- **Hierarchy**: Task → Project → Team → Organization, Report → Reportable → Organization
- **Documentation**: See `docs/timezone_handling.md` for detailed implementation

### Soft Delete Implementation
- Models: Project, Scope, Task, Note, Link, Attachment, Organization, Team, Report, ApiToken (10 total)
- Concern: SoftDeletable (app/models/concerns/soft_deletable.rb)
- **NO default_scope** - Must explicitly use `.active` scope in all queries
- Partial indexes on deleted_at for performance (algorithm: :concurrently)
- Controllers use .destroy (soft) not .destroy! (hard)
- Scopes: `active` (not deleted), `with_deleted`, `only_deleted`
- Methods: soft_delete, restore, deleted?
- **Critical:** All queries must use `.active` - Controllers, policies, MCP tools, views
- Migration uses disable_ddl_transaction! for production-safe concurrent index creation
- **ApiToken Special Behavior**:
  - Dual-state: `active` column (revocation) + `deleted_at` column (archiving)
  - `destroy` both revokes (sets active=false) AND soft deletes (sets deleted_at)
  - `revoke!` only revokes without soft deleting
  - `active` scope overridden to check: not deleted AND not revoked AND not expired
  - Additional scopes: `revoked`, `not_deleted`
- See docs/soft_delete.md for detailed implementation

## Model Context Protocol (MCP) Integration

### Overview
MCP integration enables AI assistants to interact with the Task Manager via standardized tools using the fast-mcp gem.

### Architecture
- **Framework**: fast-mcp gem (~> 1.0) with Rails integration
- **Tools**: Individual classes in `app/tools/` directory
- **Configuration**: `config/initializers/fast_mcp.rb`
- **Transport**: HTTP via Rack middleware (SSE + JSON-RPC)
- **Authentication**: API token via Authorization header
- **Documentation**: `docs/mcp_setup.md`, `docs/mcp_quick_start.md`

### Available Tools (13 total)

#### Task Tools
- **ListTasksTool**: List/filter tasks by project, scope, user, state, today status
- **GetTaskTool**: Get full task details including state history
- **CreateTaskTool**: Create new task with all attributes
- **UpdateTaskTool**: Update task attributes
- **TransitionTaskStateTool**: Change task state via state machine (validates transitions)
- **AssignTaskTool**: Assign task to user

#### Scope Tools
- **ListScopesTool**: List/filter scopes by project
- **GetScopeTool**: Get scope details with tasks and completion percentage
- **CreateScopeTool**: Create new scope in project
- **UpdateScopeTool**: Update scope attributes

#### Project Tools
- **ListProjectsTool**: List all projects
- **GetProjectTool**: Get project details with scopes and tasks

#### Audit Tools
- **ListUserChangesTool**: List changes made by current user from PaperTrail audit log with optional time range (defaults to last 24 hours)

### Endpoints

The MCP server runs as part of the Rails application:
- **HTTP Messages**: `http://localhost:3000/mcp/messages` (POST)
- **SSE Stream**: `http://localhost:3000/mcp/sse` (GET)

### Authentication & Authorization

- **API Tokens**: Users generate tokens via profile page (Security → API Tokens)
- **Token-based Auth**: Bearer token in Authorization header
- **User Scoping**: All queries scoped to authenticated user's permissions
- **Project Access**: Based on `user_party_roles` (Organization → Team → Project)

### Configuration Example

For AI assistants (Claude, Cascade, etc.):
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

### Rails Integration Pattern

Tools follow Rails conventions:
- Inherit from `ApplicationTool` (alias for `ActionTool::Base`)
- Automatic discovery and registration
- Use standard Rails models and ActiveRecord
- Integrated error handling
- Access to `current_user` and scoping helpers

### Example Tool Structure

```ruby
class MyTool < ApplicationTool
  description "Tool description"
  
  annotations(
    title: "My Tool",
    read_only_hint: true
  )
  
  arguments do
    required(:param).filled(:string).description("Param description")
  end
  
  def call(param:)
    # Access current_user, scope_tasks_by_user, etc.
    # Return result string
  end
end
```

### Example Usage
- "List all tasks in project 5"
- "Create a task called 'Fix login bug' in scope 3"
- "Transition task 42 to in_progress"
- "Assign task 15 to user 7"
- "Show me scope 8 with all its tasks"
- "What changes have I made in the last 24 hours?"
- "Show me all my changes from 2025-11-01 to 2025-11-03"

## Development Notes
- Uses modern browser requirements
- Tailwind CSS + DaisyUI for styling
- No test framework configured (system tests disabled)
- Rubocop with Rails Omakase styling
- Brakeman for security analysis
- Development uses Docker with volume mounting
- ActionView::RecordIdentifier included in controllers for `dom_id` helper