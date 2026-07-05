# Pulse — Event Subscription & Notification Pipeline

Pulse is Tudla's in-app notification system. Domain activity (project/scope/task
changes, task transitions, assignments, notes) is recorded as **events**, fanned
out asynchronously to **subscribers**, and delivered as **notifications** with a
live topbar bell, an inbox, and mark-read flows.

It follows a **three-pillar design** and was deliberately built so the `Pulse::`
namespace can later be extracted into a standalone gem / Rails engine. The second
half of this document is a step-by-step extraction guide for an agent.

---

## 1. Architecture

```
┌──────────────────────┐   ┌───────────────────────┐   ┌──────────────────────┐
│ PILLAR 1: PRODUCER   │   │ PILLAR 2:             │   │ PILLAR 3:            │
│                      │   │ ORCHESTRATION         │   │ NOTIFICATION         │
│ Pulse::Publishable   │   │                       │   │                      │
│ Pulse::Publisher ────┼──▶│ Pulse::Event          │──▶│ Pulse::Channels::    │
│ Pulse::Current       │   │  (after_create_commit)│   │   InApp              │
│                      │   │ Pulse::FanoutJob      │   │ Pulse::Notification  │
│ model callbacks,     │   │ Pulse::               │   │  (+ Turbo Stream     │
│ state machine hooks, │   │   RecipientResolver   │   │   bell broadcast)    │
│ controllers set actor│   │ Pundit visibility gate│   │ inbox UI             │
└──────────────────────┘   └───────────────────────┘   └──────────────────────┘
```

**Transactional outbox**: the `Pulse::Event` row is created *synchronously inside
the domain transaction* (so an event exists iff the domain change committed);
`Pulse::FanoutJob` is enqueued via `after_create_commit`, so fan-out only runs
after commit. Fan-out is **idempotent**: the unique index on
`notifications [event_id, user_id]` plus `create_or_find_by!` makes job retries
no-ops.

### Pillar 1 — Producer

| File | Role |
|---|---|
| `app/models/concerns/pulse/publishable.rb` | Concern mixed into host models. Auto-creates the model's `Pulse::Subscribable` container (`after_create`), and the `publishes_pulse_events(prefix:, ignore: [])` macro adds `created`/`updated` callbacks. Overrides `soft_delete`/`restore` (calling `super`) to publish `.deleted`/`.restored`, because `SoftDeletable` uses `update_column` and fires no AR callbacks. Also provides `subscribe`/`unsubscribe`/`subscribed?`/`pulse_subscribers`/`publish_pulse_event`. |
| `app/services/pulse/publisher.rb` | `Pulse::Publisher.publish(subject:, action:, metadata: {}, user: :current, actor_type:, actor_label:)` — the single entry point that creates the event. Captures denormalized display metadata (`subject_type/id/name`, `actor_name`) at publish time so notification text survives later rename/deletion of the subject. |
| `app/models/pulse/current.rb` | `ActiveSupport::CurrentAttributes` carrying `user`, `actor_type`, `actor_label`. `resolved_actor_type` falls back: explicit → `"user"` if a user is set → `"system"`. |

**Actor model** — events support three actor types (`events.actor_type`):
- `user` — a signed-in human. `ApplicationController#set_pulse_actor` sets
  `Pulse::Current.user = current_user`.
- `agent` — an MCP client. `McpController#set_pulse_agent_actor` sets the token's
  user, `actor_type: "agent"`, and `actor_label` = the `ApiToken` name.
- `system` — anything else (rake tasks, runners, jobs). The default when no
  `Pulse::Current.user` is set; `events.user_id` is nullable for this case.

**Where events are published from:**
- `Project`, `Scope`, `Task` include `Pulse::Publishable` (**after**
  `SoftDeletable` — the `super` chain depends on this order) and declare
  `publishes_pulse_events prefix: ..., ignore: [...]`. The ignore lists suppress
  noise from cached-estimate columns, positioning columns, denormalized state
  columns, etc. An update touching only ignored columns publishes nothing.
- State machines publish via the shared **`PulseTransitionPublishing`** mixin
  (`app/state_machines/pulse_transition_publishing.rb`, host-owned): it derives
  `from_state`/`to_state` metadata, skips the machine's initial self-transition,
  and resolves the acting user from `transition.metadata["user_id"]` (passed as
  an explicit `user:` override; `Pulse::Current` as fallback).
  `TaskStateMachine` and `ProjectRiskStateMachine` use the
  `publishes_pulse_transitions action:, initial:, transitions:` macro, which
  installs an `after_transition(after_commit: true)` hook publishing safely —
  the transition is already committed, so a publish failure is logged, never
  raised. `ProjectLifecycleStateMachine` calls
  `PulseTransitionPublishing.publish_transition(..., safely: false)` from its
  synchronous hook — strictly, inside the transition's transaction.
- `Task#publish_pulse_assignment_change` (`after_save` on
  `saved_change_to_responsible_user_id?`, so it also fires for tasks created
  with an assignee) publishes `task.assigned` and auto-subscribes the new
  assignee; clearing the assignee publishes `task.unassigned` with the
  previous assignee in metadata.
- `Note#publish_pulse_note_event` (`after_create`) publishes `note.created`
  against the note's parent record (project/scope/task) if that parent is
  publishable.
- Creating a publishable record auto-subscribes the current actor
  (`Pulse::Current.user`).

**Event naming** — Stripe-style `<object>.<past_tense_verb>` dot notation,
validated against `Pulse::Event::CATALOG` (plus
`Pulse.config.catalog_extensions`). Each action maps 1:1 to an i18n key under
`pulse.events.*` in `config/locales/en.yml`. Current catalog:
`project|scope|task . created|updated|deleted|restored`, `project.transitioned`,
`project.risk_changed`, `task.transitioned`, `task.assigned`, `task.unassigned`,
`note.created`. `spec/models/pulse/event_catalog_spec.rb` guards the catalog:
it fails CI if app code publishes an action missing from the catalog or if a
catalog action has no i18n copy — publishing an uncataloged action from a
create/update callback would otherwise break the host model's save in
production.

### Pillar 2 — Orchestration

| File | Role |
|---|---|
| `app/models/pulse/event.rb` | Validates action against catalog and `actor_type` against `user/agent/system` (`user` requires a `user` record). `after_create_commit` enqueues `Pulse::FanoutJob`. |
| `app/jobs/pulse/fanout_job.rb` | Loads the event (warn + skip if gone), asks the configured recipient resolver for candidates, then filters: dedupe, **exclude the actor** (no self-notification), and **re-check visibility** via the configured visibility filter (access-revocation safety; a filter failure counts as not visible). Hands survivors to every configured channel. |
| `app/services/pulse/visibility_filter.rb` | Default visibility gate: Pundit `show?` per recipient. |
| `app/services/pulse_visibility_filter.rb` | **Host-owned** batched replacement: one `UserPartyRole` query for the whole recipient set (project/team/org membership + task ownership), mirroring `#show?` of the subject policies. `spec/services/pulse_visibility_filter_spec.rb` guards the agreement. |
| `app/services/pulse/recipient_resolver.rb` | Default resolver: the subscribable's subscription users. |
| `app/services/pulse_recipient_resolver.rb` | **Host-owned** subclass (note: top-level, *not* in `Pulse::`). Adds project admins (admin role on the project, its team, or its organization — same semantics as `ProjectPolicy#admin_on_project_scope?`) as recipients when a task transitions to `in_review` — the replacement for the old `notify_reviewers!` breadcrumb. |

### Pillar 3 — Notification

| File | Role |
|---|---|
| `app/services/pulse/channels/base.rb` | Channel adapter interface: `#deliver(event, recipients)` raises `NotImplementedError`. |
| `app/services/pulse/channels/in_app.rb` | Creates one `Pulse::Notification` per recipient in a single `insert_all` (`ON CONFLICT DO NOTHING` via the unique index — idempotent), then broadcasts the bell explicitly for rows actually inserted (`insert_all` skips AR callbacks). Badge counts for all recipients come from one grouped `COUNT` and are passed into each broadcast render — the indicator partial only runs its own (capped) `COUNT` when no precomputed count is given (topbar render, single-notification broadcasts). |
| `app/jobs/pulse/retention_job.rb` | Daily pruning (`config/recurring.yml`, 3am): read notifications after 30 days, unread after 90, then events older than 90 days with no remaining notifications. Batched `delete_all` — safe because notifications have no destroy callbacks and events are only removed once childless. |
| `app/models/pulse/notification.rb` | `unread`/`read` scopes, `mark_read!`. `after_create_commit` broadcasts the bell partial to `"user_#{user_id}_notifications"` via `Turbo::StreamsChannel` (guarded, rescued, `can_update: false`). |
| `app/controllers/notifications_controller.rb` | Inbox (`policy_scope` + Pagy, 25/page), `mark_read` (then redirects to the subject via `polymorphic_path`, falling back to the inbox), `mark_all_read`. |
| `app/views/notifications/` | `_indicator.html.erb` (bell + unread badge, capped "9+"), `_notification.html.erb`, `index.html.erb`. |
| `app/views/application/_topbar.html.erb` | Renders the indicator and `turbo_stream_from "user_#{current_user.id}_notifications"`. |
| `app/helpers/notifications_helper.rb` | `notification_text` — i18n lookup by `event.action` with interpolations (`actor`, `subject`, `from_state`, `to_state`, `assignee`) and a generic fallback key. |

Subscribe/unsubscribe UI lives in `SubscribablesController` (subscribe toggle,
`authorize :show?` on the subject) and `SubscriptionsController` (unsubscribe,
owner-checked). Currently the manual toggle is only rendered on the Project show
page; Scope/Task rely on auto-subscription (creator, assignee).

### Data model

Four tables, **unprefixed** (they predate the namespace;
`Pulse.table_name_prefix` returns `""`):

```
subscribables  — polymorphic container (subscribable_type/_id), delegated_type
subscriptions  — user_id + subscribable_id, UNIQUE [user_id, subscribable_id]
events         — subscribable_id, user_id (nullable), actor_type (default "user"),
                 actor_label, action, metadata jsonb
notifications  — event_id + user_id, read_at, UNIQUE [event_id, user_id],
                 partial index on unread, [user_id, created_at DESC]
```

`Organization → Team → Project → Scope → Task`: only Project/Scope/Task are
subscribable (configured, not hardcoded).

### Configuration & host wiring

All app-specific knowledge is declared in **`config/initializers/pulse.rb`**
(inside `to_prepare` for reloading):

```ruby
Pulse.configure do |config|
  config.subscribable_types = %w[Project Scope Task]        # delegated_type list
  config.channels           = [ "Pulse::Channels::InApp" ]  # class-name strings
  config.recipient_resolver = "PulseRecipientResolver"      # host subclass
  config.visibility_filter  = "PulseVisibilityFilter"       # batched host filter
  # config.catalog_extensions = %w[...]                     # extra event actions
end
```

`Pulse.channels` constantizes lazily (dev reloading safety);
`Pulse.recipient_resolver` and `Pulse.visibility_filter` each accept a String,
`nil` (default implementation), or any object with the matching `call`.

Authorization is host-owned: `app/policies/subscription_policy.rb`,
`notification_policy.rb`, `subscribable_policy.rb`, `event_policy.rb`. The Pulse
models point at them via `def self.policy_class`, delegating visibility to the
underlying subject's `show?`.

### Operational notes

- **Cable adapter**: development uses `solid_cable`, *not* `async` — Pulse
  broadcasts originate in the `bin/jobs` process, and the async adapter is
  in-process only. Reverting `config/cable.yml` silently kills live bell
  updates in development.
- **Backfill**: `bin/rails pulse:backfill_subscribables` creates missing
  `Subscribable` rows for pre-existing records of all configured types.
- **Retention**: fan-out on write grows `notifications` as events × recipients.
  `Pulse::RetentionJob` (scheduled daily in `config/recurring.yml`, production
  block) prunes read notifications after 30 days, unread after 90, and
  notification-less events after 90. Deleted unread rows are not re-broadcast;
  the badge corrects on the user's next page load.
- **Tests**: factories in `spec/factories/pulse.rb`
  (`pulse_subscribable/subscription/event/notification`); specs under
  `spec/models/pulse/`, `spec/jobs/pulse/`, `spec/requests/`, `spec/policies/`.
  Note that Rails 8 transactional tests **do** fire `after_create_commit`, so
  creating a `Pulse::Event` in a spec enqueues the fan-out job.

---

## 2. Extraction guide: turning Pulse into a gem / Rails engine

Audience: an agent tasked with extracting Pulse. The code was written to make
this mostly mechanical — the boundary is "everything under `Pulse::` moves,
everything host-specific already lives outside it."

### 2.1 What moves into the engine (host-agnostic today)

| Current path | Engine path |
|---|---|
| `app/models/pulse.rb` | `lib/pulse.rb` (+ `lib/pulse/engine.rb`) |
| `app/models/pulse/{current,event,notification,subscribable,subscription}.rb` | `app/models/pulse/` |
| `app/models/concerns/pulse/publishable.rb` | `app/models/concerns/pulse/` |
| `app/jobs/pulse/fanout_job.rb` | `app/jobs/pulse/` |
| `app/services/pulse/{publisher,recipient_resolver}.rb`, `app/services/pulse/channels/*` | `app/services/pulse/` |
| `spec/factories/pulse.rb`, `spec/models/pulse/`, `spec/jobs/pulse/` | engine spec suite (against a dummy app) |

### 2.2 What stays in the host (already outside `Pulse::`)

- `config/initializers/pulse.rb` — becomes the generated installer initializer.
- `app/services/pulse_recipient_resolver.rb` — host resolver (knows
  `UserPartyRole`, project admins, `in_review`).
- `app/services/pulse_visibility_filter.rb` — host visibility filter (knows
  the org→team→project hierarchy and task ownership).
- `app/state_machines/pulse_transition_publishing.rb` — host mixin for
  Statesman machines (knows `User` and the transition-table conventions).
- All four policies in `app/policies/` — they know the org→team→project
  hierarchy.
- Controllers (`notifications_controller.rb`, `subscribables_controller.rb`,
  `subscriptions_controller.rb`), views (`app/views/notifications/`), helper,
  routes, topbar integration, `en.yml` keys — extract these as engine
  *generators/templates* rather than engine-served views, since they use
  host-specific styling (DaisyUI, iconify) and Pagy.
- The `include Pulse::Publishable` + `publishes_pulse_events` declarations in
  `Project`/`Scope`/`Task`, the `publishes_pulse_transitions` declarations in
  the state machines, `Note#publish_pulse_note_event`, and the
  `set_pulse_actor` / `set_pulse_agent_actor` before-actions.
- `lib/tasks/pulse.rake` (or ship it in the engine — it only uses
  `Pulse.config.subscribable_types`, so it's portable).

### 2.3 Known couplings to break (the actual work)

These are the only places engine-bound code currently assumes Tudla:

1. **Table names** — `Pulse.table_name_prefix` returns `""` because the tables
   predate the namespace. In the engine, make the prefix configurable
   (`config.table_name_prefix`, default `"pulse_"`) and have Tudla set `""`.
   The engine's install migrations should create `pulse_*` tables; Tudla skips
   them (its tables already exist).
2. **`User` class** — `Event`, `Subscription`, `Notification`,
   `RecipientResolver`, and `FanoutJob` reference `User`/`user` associations
   directly, and `Publisher`/`Event#actor_name` call `user.display_name`.
   Add `config.user_class` (default `"User"`) and
   `config.user_display_name_method` (default `:display_name`, or accept a
   lambda). Use `belongs_to :user, class_name: Pulse.config.user_class` (inside
   `to_prepare` or a lazy resolver so reloading works).
3. **Pundit** — fan-out visibility is already configurable
   (`config.visibility_filter`; the engine default `Pulse::VisibilityFilter`
   still assumes Pundit — make it degrade to `->(*) { true }` when Pundit is
   undefined). Remaining work: the models declare `policy_class` pointing at
   host constants (`SubscriptionPolicy`, etc.) — drop those overrides from
   engine models; the host reopens/configures them, or the engine exposes
   `config.policy_classes = { subscription: "...", ... }`.
4. **`ApplicationJob` / `ApplicationRecord`** — `FanoutJob < ApplicationJob`
   and models inherit host base classes. In the engine define
   `Pulse::ApplicationRecord` (abstract) and `Pulse::ApplicationJob`, with
   `config.parent_job_class` if the host wants Solid Queue settings inherited.
5. **`SoftDeletable` assumption** — `Publishable#soft_delete/#restore` call
   `super` and exist purely for Tudla's callback-less soft delete. Guard them:
   only define the overrides if the including class responds to
   `soft_delete`/`restore` (e.g. define in an `included do ... if
   base.method_defined?(:soft_delete)` block), so the concern works in hosts
   without soft delete.
6. **Turbo broadcast in `Notification`** — the `after_create_commit` broadcast
   assumes Turbo, a `"user_#{id}_notifications"` stream name, and a host
   partial `notifications/indicator`. Move this out of the model into a
   configurable delivery hook on the InApp channel
   (`config.in_app_broadcast = ->(notification) { ... }`, default no-op), and
   let the installer generator wire up the Turbo version.
7. **i18n keys** — `pulse.events.*` live in the host locale file. Ship engine
   defaults for the built-in catalog; hosts override per action and add keys
   for `catalog_extensions`.

Grep check before cutting the gem — these must return no hits inside engine code:

```
grep -rn "Project\|Scope\|Task\|UserPartyRole\|Organization\|Team" \
  app/models/pulse* app/models/concerns/pulse app/jobs/pulse app/services/pulse
```

(Currently clean; keep it that way.)

### 2.4 Suggested engine skeleton

```
pulse/
  lib/pulse.rb                    # module + Config (port of app/models/pulse.rb)
  lib/pulse/engine.rb             # isolate_namespace Pulse
  lib/pulse/version.rb
  lib/tasks/pulse.rake
  app/models/pulse/...            # event, notification, subscribable, subscription, current
  app/models/concerns/pulse/publishable.rb
  app/jobs/pulse/fanout_job.rb
  app/services/pulse/...          # publisher, recipient_resolver, channels/
  db/migrate/                     # create pulse_* tables (skipped by Tudla)
  lib/generators/pulse/install/   # initializer, migration copy, optional
                                  # controllers/views/routes templates
  config/locales/en.yml           # default pulse.events.* texts
  spec/dummy/                     # dummy app with a PORO-ish User + one subscribable model
```

Config surface after extraction (superset of today's `Pulse::Config` struct —
consider migrating the Struct to a plain class with defaults):

```ruby
Pulse.configure do |config|
  config.subscribable_types  = %w[Project Scope Task]
  config.channels            = [ "Pulse::Channels::InApp" ]
  config.recipient_resolver  = "PulseRecipientResolver"
  config.catalog_extensions  = []
  config.table_name_prefix   = ""                    # new — Tudla override
  config.user_class          = "User"                # new
  config.user_display_name_method = :display_name    # new
  config.visibility_filter   = "PulseVisibilityFilter" # already implemented in-repo
  config.in_app_broadcast    = ->(notification) { ... }  # new — Turbo bell hook
end
```

### 2.5 Extraction order of operations

1. In-repo prep (no gem yet): apply §2.3 items 1–6 as refactors inside Tudla;
   the full spec suite (`bundle exec rspec`, run in Docker) is the safety net.
   After this, engine-bound code has zero host constants.
2. Create the engine (`rails plugin new pulse --mountable --database=postgresql
   --skip-javascript`), move the §2.1 files, add the dummy app, port the specs.
3. Point Tudla's Gemfile at the engine (`path:` first), delete the moved files,
   keep the initializer + host resolver + policies + UI. Set
   `config.table_name_prefix = ""` so existing tables keep working — **no data
   migration needed**.
4. Run Tudla's full suite + the engine suite; smoke-test the live pipeline
   (publish an event from `rails runner`, watch the bell update — remember the
   solid_cable requirement and the `sleep infinity | bin/dev` detached-boot
   quirk).
5. Only then publish/version the gem and switch the Gemfile from `path:` to a
   released version.

### 2.6 Behavioural invariants to preserve (test these in the engine)

- Event row is created in the domain transaction; fan-out only after commit.
- Fan-out is idempotent under retries (unique `[event_id, user_id]`).
- The actor never receives their own notification.
- Recipients failing the visibility check are silently dropped (revoked access).
- `actor_type: "user"` requires a user; system events have `user_id: nil` and
  render as "System" (or `actor_label`).
- Updates touching only ignored columns publish no event.
- Unknown actions (outside catalog + extensions) fail validation.
- Creating a record auto-subscribes the current actor; assignment
  auto-subscribes the assignee — including when the assignee is set at
  creation time.
- Publishes that run after the domain change is already persisted (soft
  delete/restore, after-commit state-machine hooks) never raise on failure;
  they log and return nil.
