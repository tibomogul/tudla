# Model Layer

## Model Inventory (25 models)

### Core Hierarchy
| Model | Concerns | Key Associations |
|-------|----------|-----------------|
| Organization | SoftDeletable | has_many :teams, :user_party_roles; timezone field |
| Team | SoftDeletable | belongs_to :organization; has_many :projects |
| Project | SoftDeletable, PaperTrail | belongs_to :team; has_many :scopes, :tasks; ProjectRiskStateMachine |
| Scope | SoftDeletable, PaperTrail | belongs_to :project; has_many :tasks |
| Task | SoftDeletable, EstimateCacheable, PaperTrail | belongs_to :project, :scope (optional), :responsible_user; TaskStateMachine |
| User | Devise (8 modules + Google/Microsoft OAuth) | has_many :user_party_roles; `from_omniauth`, `teams_for_project_creation` |

### State Transition Models
| Model | Broadcasts To |
|-------|--------------|
| TaskTransition | "task_{id}_history" (append) — JSONB metadata with user_id |
| ProjectRiskTransition | "project_{id}_risk_history" (append) — JSONB metadata |

### Delegated Type Containers
| Container | Concrete Model | Concerns | Attachable Types |
|-----------|---------------|----------|-----------------|
| Notable | Note | SoftDeletable, PaperTrail | Project, Scope, Task, Pitch, Team, Organization |
| Linkable | Link | SoftDeletable, PaperTrail | Project, Scope, Task, Pitch, Team, Organization |
| Attachable | Attachment | SoftDeletable, PaperTrail | Project, Scope, Task, Pitch, Team, Organization |
| Subscribable | Subscription | — | Project, Scope, Task |
| Reportable | Report | SoftDeletable | Project, Team |

### Supporting Models
| Model | Purpose |
|-------|---------|
| UserPartyRole | Polymorphic join: user → org/team/project with role (admin/member) |
| ApiToken | MCP auth; dual-state: `active` (revocation) + `deleted_at` (archiving) |
| ReportRequirement | IceCube scheduling for recurring reports; `next_occurrence`, `reminder_date` |
| Event | Tracks actions on subscribables with JSONB metadata |
| Notification | User notifications for events; tracks `read_at` |

## Concerns

### SoftDeletable (10 models)
- Sets `deleted_at` instead of destroying record
- **NO default_scope** — all queries MUST use `.active` explicitly
- Scopes: `active`, `with_deleted`, `only_deleted`
- Methods: `soft_delete`, `restore`, `deleted?`
- `destroy` overridden → soft delete; `destroy!` → hard delete
- ApiToken override: `destroy` also sets `active=false` (revokes)

### EstimateCacheable (Task only)
- Maintains denormalized sums on parent Scope and Project
- Columns: `cached_unassisted_estimate`, `cached_ai_assisted_estimate`, `cached_actual_manhours`
- Auto-triggers: after create, update (if estimates or parent changed), destroy, restore
- Handles reassignment: recalculates BOTH old and new parent records
- Uses SQL SUM with `.active` scope for soft delete compatibility
- Backfill: `docker compose exec rails bash -lc "bin/rails estimate_cache:backfill"`

## Broadcast Models (6)
All use named method + ActionCable guard + error rescue pattern:
- **Task** → "tasks" stream (replace)
- **Project** → "projects" stream (replace)
- **TaskTransition** → "task_{id}_history" (append)
- **ProjectRiskTransition** → "project_{id}_risk_history" (append)
- **Note** → "{type}_{id}_notes" (replace)
- **Link** → "{type}_{id}_links" (replace)

## PaperTrail (7 models)
Task, Scope, Project, Pitch, Note, Link, Attachment
- Task skips: `backlog_position`, `today_position`, `scope_position`, `in_today`
- Scope skips: `project_position`
- Whodunnit tracked via `PaperTrail.request.whodunnit` (set in ApplicationController)

## State Machines (Statesman)
- **Task.state** and **Project.risk_state** are denormalized columns updated by `after_transition` callbacks
- Never assign state directly — always use `state_machine.transition_to!(state, metadata)`
- Query: `Task.in_state(:new)`, `Task.not_in_state(:done)` (Statesman adapter)
- Metadata: `transition_to!(:in_progress, user_id: current_user.id)`

## Critical Rules
- ALWAYS use `.active` scope on soft-deletable models (no exceptions)
- Never update `cached_*_estimate` columns directly (EstimateCacheable handles it)
- Never assign `task.state =` directly (use `state_machine.transition_to!`)
- Broadcast methods MUST have `ActionCable.server.pubsub.respond_to?(:broadcast)` guard
- Broadcast partials MUST set `can_update: false` (no Devise context in broadcasts)
- PaperTrail: add position/ordering columns to `skip` array for new sortable fields
