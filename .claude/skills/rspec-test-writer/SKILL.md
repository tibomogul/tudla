---
name: rspec-test-writer
description: This skill should be used when the user asks to "write a spec", "add tests", "test this model/policy/service/tool", "raise coverage", "create an rspec test", or any task involving authoring RSpec tests in the Tudla (Rails 8.1) codebase. Encodes project conventions for factories, the UserPartyRole access hierarchy, Statesman state machines, Pundit, Devise, soft delete, estimate caching, MCP tools, ViewComponents, and PaperTrail so new specs match house style and run cleanly under Docker.
---

# RSpec Test Writer for Tudla

This skill produces RSpec tests that match Tudla's existing conventions. It is tuned for Rails 8.1 / Ruby 3.3.4 / RSpec 8 / FactoryBot / Devise / Pundit / Statesman / PaperTrail / ViewComponent / the `mcp` gem, all running under PostgreSQL 18 in Docker.

The goal is specs that lock down current behaviour exactly — including the soft-delete, estimate-cache, and lifecycle quirks that are easy to break in a refactor. A spec that would still pass if the production code broke is worse than no spec.

## When to use

Apply this skill whenever a user request involves writing, extending, or fixing RSpec specs anywhere under `spec/`. The primary reference for the codebase is the root `AGENTS.md` plus `spec/AGENTS.md`; load those when you need architecture detail.

For a prioritized list of what to test next, consult `references/coverage-targets.md`.

## Where tests live

Mirror the path of the code under test:

| Code under test | Spec path |
| --- | --- |
| `app/models/foo.rb` | `spec/models/foo_spec.rb` |
| `app/models/concerns/foo.rb` | `spec/models/foo_spec.rb` |
| `app/policies/foo_policy.rb` | `spec/policies/foo_policy_spec.rb` |
| `app/state_machines/foo_state_machine.rb` | `spec/state_machines/foo_state_machine_spec.rb` |
| `app/services/foo.rb` | `spec/services/foo_spec.rb` |
| `app/components/foo_component.rb` | `spec/components/foo_component_spec.rb` |
| `app/tools/foo_tool.rb` | `spec/tools/foo_tool_spec.rb` |
| `app/helpers/foo_helper.rb` | `spec/helpers/foo_helper_spec.rb` |
| `app/mailers/foo_mailer.rb` | `spec/mailers/foo_mailer_spec.rb` |
| `app/controllers/foos_controller.rb` | `spec/requests/foos_spec.rb` (prefer request specs) |

`spec/services/`, `spec/policies/`, `spec/state_machines/`, `spec/tools/`, and `spec/components/` already exist. Pass `type:` explicitly on the describe block (`type: :model`, `:request`, `:policy`, `:component`, `:helper`, `:mailer`) — `infer_spec_type_from_file_location!` is **off** in `spec/rails_helper.rb`, so the type metadata that mixes in Devise/Capybara/url helpers only applies when you set it.

## Always-included boilerplate

Every spec begins:

```ruby
require "rails_helper"

RSpec.describe MyClass, type: :model do
  # ...
end
```

Never `require "spec_helper"` directly from a spec — `rails_helper` requires it, and bypassing it skips Devise/FactoryBot/Capybara/TimeHelpers setup wired in `spec/rails_helper.rb`.

`spec/rails_helper.rb` already mixes in, by type:

- `Devise::Test::IntegrationHelpers` for `type: :request` — gives you `sign_in(user)`.
- `Devise::Test::ControllerHelpers` for `type: :controller` and `type: :view`.
- `FactoryBot::Syntax::Methods` everywhere — call `create(:user)`, not `FactoryBot.create(:user)`.
- `ActiveSupport::Testing::TimeHelpers` everywhere — `travel_to` is available without any extra include.
- `use_transactional_fixtures = true` — every example rolls back. Do not call `DatabaseCleaner`.

`mocks.verify_partial_doubles = true` is on (`spec/spec_helper.rb`). Stubs against typo'd or removed methods raise — good. Fix the stub, never disable verification. `config.order = :random`; never let one example mutate state another reads.

## Factories — the rule

Tudla uses **FactoryBot factories only**. There are no lookup/reference fixtures (`config.fixture_paths` points at an empty `spec/fixtures`). Factories live in `spec/factories/<singular>.rb` and define a **minimal valid record**:

```ruby
# spec/factories/user.rb
FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@company.com" }
    password  { "password" }
    confirmed_at { 1.day.ago }
    confirmation_sent_at { 1.day.ago }
    sequence(:confirmation_token) { |n| "token#{n}" }
  end
end
```

Project conventions for factories:

- Always `FactoryBot.define`. Block form for every attribute (`password { "password" }`).
- The `user` factory **pre-confirms** (Devise) — never build a user without `confirmed_at`/`confirmation_token` or sign-in will fail.
- Use `sequence(:x)` for values that must be unique (email, confirmation_token, name). Literals (`name { "Task1" }`) are fine when uniqueness does not matter.
- Build the domain graph with explicit associations passed at call time:
  `create(:project, team: team)`, `create(:task, project: project, scope: scope)`.
- Prefer **traits** over duplicate factories. The `user_party_role` factory is the canonical example:

  ```ruby
  factory :user_party_role do
    user
    role { "member" }

    trait :org_admin do
      association :party, factory: :organization
      role { "admin" }
    end
    # ...team_admin, team_member, org_member
  end
  ```

See `examples/factory.rb` for a richer template with traits, transient attributes, and a callback.

## Granting access via UserPartyRole — the hierarchy

Tudla's domain is `Organization → Team → Project → Scope → Task`. Who can see/do what is driven by **`UserPartyRole`**, a polymorphic join assigning a user a `role` (`"admin"` / `"member"`) on an Organization, Team, or Project. There is no employment chain — granting access is one line:

```ruby
UserPartyRole.create!(user: user, party: organization, role: "admin")
UserPartyRole.create!(user: user, party: team,         role: "member")
UserPartyRole.create!(user: user, party: project,      role: "member")
```

Policy scopes resolve **down** the hierarchy: a role on an Organization grants access to its Teams and Projects; a role on a Team grants access to its Projects; a role only on a Project does **not** grant access up to the org. When a spec needs a user who can act on a record, create the record's org/team/project graph, then grant the user the appropriate `UserPartyRole`. See `spec/policies/pitch_policy_spec.rb` for the canonical pattern (member vs admin vs non-member, and team-role-only vs project-role-only edge cases).

After changing a user's memberships mid-test, call `user.bust_organizations_cache` if the code under test reads the memoized membership set (the policy specs do this when they delete a role with `delete_all` to bypass the prune callback).

## Authoring patterns

- Prefer `let` / `let!` over `before { @x = ... }`. Use `let!` only when eager creation matters (e.g. counting rows, or a record must exist before the example body).
- Nest one `context` per dimension being varied: `context "when admin"`, `context "with a scope"`. Keep `it` strings present-tense, no "should".
- `describe "#instance_method"` / `describe ".class_method"` for behaviour; `context` to vary inputs.
- Pass overrides to `create`/`build` explicitly: `create(:task, project: project, unassisted_estimate: 10)`.
- One logical behaviour per `it`; multiple `expect`s are fine when they describe that one behaviour.

## Statesman state machines

Tudla uses **Statesman**, not AASM. Five machines exist: `TaskStateMachine`, `ProjectRiskStateMachine`, `ProjectLifecycleStateMachine`, `PitchStateMachine`, `CycleStateMachine`. The golden rule (root `AGENTS.md` anti-patterns): **never assign state directly** — always go through the machine.

```ruby
task.state_machine.transition_to!(:in_progress, user_id: user.id)   # bang: raises on failure
task.state_machine.can_transition_to?(:in_progress)                 # => true/false
task.current_state                                                  # current state string
Task.in_state(:new)                                                 # Statesman query adapter
```

Test, for each machine:

1. **Initial state** after creation (`expect(task.current_state).to eq("new")`).
2. **Each allowed transition** — call `transition_to!`, assert the new state and any side effects.
3. **Forbidden transitions** raise `Statesman::TransitionFailedError`:

   ```ruby
   expect { project.lifecycle_state_machine.transition_to!(:done) }
     .to raise_error(Statesman::TransitionFailedError)
   ```
4. **Guards** — exercise both branches. `TaskStateMachine` guards `:in_progress` on `responsible_user` + both estimates being present; a task missing either cannot enter `in_progress`.
5. **`after_transition` side effects** — assert the effect, not just that a method was called (e.g. lifecycle propagation sets `project_lifecycle_state` on every child scope/task; the transition is wrapped in Statesman's transaction so a failed propagation rolls the transition row back).

Detail and worked patterns: `references/statesman-and-papertrail.md`. Worked example: `examples/state_machine_spec.rb`.

## Devise + Pundit

Devise scope is the default `:user`. In **request specs**, `sign_in(user)` works directly (IntegrationHelpers are mixed in):

```ruby
RSpec.describe "/tasks", type: :request do
  let(:user) { create(:user) }
  before { sign_in(user) }

  describe "GET /index" do
    it "renders successfully" do
      get tasks_url
      expect(response).to be_successful
    end
  end
end
```

For **authorization**, the cheapest, highest-signal tests drive the Pundit policy directly — no controller needed. A policy action returns a boolean; the Scope resolves a relation:

```ruby
expect(PitchPolicy.new(admin, pitch).update?).to be true
expect(PitchPolicy.new(non_member, pitch).show?).to be false

resolved = PitchPolicy::Scope.new(user, Pitch).resolve
expect(resolved).to include(visible_pitch)
expect(resolved).not_to include(other_org_pitch)
```

Set up the actors with `UserPartyRole` grants (see above). Cover the boundary of the rule under test: e.g. for an admin-only action, test admin allowed + plain member denied + non-member denied. Detail: `references/authorization.md`. Worked example: `examples/policy_spec.rb`.

## Soft delete

10 models include `SoftDeletable`. There is **no `default_scope`**. Always query `.active` and assert deletion via the flag, not row count:

```ruby
task.soft_delete
expect(Task.active).not_to include(task)
expect(task.deleted_at).to be_present

task.restore
expect(Task.active).to include(task)
```

When testing any scope, controller, policy, MCP tool, or service that reads soft-deletable models, assert that soft-deleted records are excluded — this is a common real bug.

## Estimate caching

`EstimateCacheable` maintains denormalized `cached_unassisted_estimate`, `cached_ai_assisted_estimate`, and `cached_actual_manhours` on `scopes` and `projects`. **Never write those columns directly** — they are maintained by callbacks. Test by changing tasks and asserting the parent's cached sums after `reload`:

```ruby
create(:task, scope: scope, project: project, unassisted_estimate: 10, ai_assisted_estimate: 5, actual_manhours: 3)
scope.reload
expect(scope.cached_unassisted_estimate).to eq(10)
```

Cover create, update, move-between-scopes, move-between-projects, destroy (decrements), restore (re-increments), and nil-treated-as-0. Mirror `spec/models/estimate_cacheable_spec.rb`.

**`destroy`/`restore` vs bare `soft_delete`** — `EstimateCacheable` overrides `#destroy` and `#restore` to soft-delete/restore **and** recalc the caches. Bare `#soft_delete` is just an `update_column(:deleted_at, …)` that skips callbacks, so it flips the flag but leaves `cached_*` untouched. Use `destroy`/`restore` in cache-rollup tests; `soft_delete` is fine when you only need to assert `.active` exclusion.

## MCP tools

Tools in `app/tools/` inherit from `ApplicationTool`. They are constructed with a server context hash and called via `execute`:

```ruby
let(:tool) { described_class.new({ user: user }) }
result = tool.execute(team_id: team.id)
```

Every tool query must use `.active` and Pundit authorization. Test that results include the right records, exclude other users'/teams'/orgs' records, and **exclude soft-deleted records**. Audit-trail tools need PaperTrail enabled (see below). Mirror `spec/tools/list_user_changes_tool_spec.rb`. Worked example: `examples/tool_spec.rb`.

## ViewComponents

Component specs use `type: :component` and include the ViewComponent/Capybara helpers in the spec itself (they are not globally configured):

```ruby
RSpec.describe NoteRowComponent, type: :component do
  include ViewComponent::TestHelpers
  include Capybara::RSpecMatchers

  it "renders the title" do
    render_inline(described_class.new(note: note))
    expect(page).to have_text("Hello")
    expect(page).to have_css(".badge", text: "edited")
  end
end
```

Stub policy gating with an `instance_double(FooPolicy, edit?: true)` wired through `vc_test_controller` (see `spec/components/note_row_component_spec.rb`). Broadcast-rendered partials run with `can_update: false` (no Devise context) — components must tolerate that. Worked example: `examples/component_spec.rb`.

## PaperTrail

PaperTrail is wired on several models (`has_paper_trail`). Two patterns are in use; pick the one that fits:

- **Block form** (component spec style) when you need a specific whodunnit for one change:

  ```ruby
  PaperTrail.request(whodunnit: other.id) { note.update!(content: "edited") }
  expect(note.versions.last.whodunnit).to eq(other.id.to_s)
  ```
- **Enable/disable toggle** (tool spec style) when a whole example group exercises versioning:

  ```ruby
  before { PaperTrail.enabled = true }
  after  { PaperTrail.enabled = false }
  # set whodunnit per change:
  PaperTrail.request.whodunnit = user.id.to_s
  ```

Assert `record.versions.last.event` (`"create"`/`"update"`/`"destroy"`), `.whodunnit`, and `.changeset` for the diff. Do not assert that every model is audited — a missing `has_paper_trail` is the right answer when a model was not meant to be tracked. Detail: `references/statesman-and-papertrail.md`.

## Background jobs (Solid Queue / ActiveJob)

Jobs are ActiveJob classes run by Solid Queue. Assert enqueueing or execution with Rails' job matchers / helpers:

```ruby
expect { thing.do_it }.to have_enqueued_job(MyJob).with(record)

perform_enqueued_jobs do
  thing.do_it
end
expect(record.reload).to be_done
```

`have_enqueued_job` / `perform_enqueued_jobs` come from `ActiveJob::TestHelper`; include it in the spec (`include ActiveJob::TestHelper`) when needed. Worked example: `examples/job_spec.rb`.

## Mailers

Build the mail object and assert headers/body via `ActionMailer::Base.deliveries` or the returned `Mail::Message`:

```ruby
mail = OrganizationMailer.user_added(user: user, party: organization, added_by: admin)
expect(mail.to).to eq([user.email])
expect(mail.subject).to eq("You've been added to #{organization.name}")
expect(mail.body.encoded).to include(organization.name)
```

`delivery_method = :test` in test env — `deliveries` accumulates; clear it in a `before` when counting. Mirror `spec/mailers/organization_mailer_spec.rb`. Worked example: `examples/mailer_spec.rb`.

## Time and timezone

Use `travel_to` (already available) to freeze the clock for any date-sensitive spec:

```ruby
around { |ex| travel_to(Time.zone.local(2026, 1, 15, 9)) { ex.run } }
```

Tudla's timezone is **organization-level** (default `"Australia/Brisbane"`), surfaced via `format_in_timezone`. When asserting formatted times, compare against the value produced through `format_in_timezone`/the org timezone, never the browser/UTC clock. Never rely on bare `Date.today` / `Time.now` in a date-sensitive assertion — freeze time so the test is deterministic and would actually catch a regression. Detail: `references/conventions.md`.

## Running tests

All commands go through Docker (never on the host):

```bash
# Full suite
docker compose exec rails bash -lc "bundle exec rspec"

# Single file
docker compose exec rails bash -lc "bundle exec rspec spec/models/task_spec.rb"

# Single example by line
docker compose exec rails bash -lc "bundle exec rspec spec/models/task_spec.rb:42"
```

Or use the bundled wrapper, which also prints SimpleCov coverage:

```bash
bash .claude/skills/rspec-test-writer/scripts/run-coverage.sh
bash .claude/skills/rspec-test-writer/scripts/run-coverage.sh spec/models/task_spec.rb
```

After a green run, `coverage/.last_run.json` holds the new percentage. Compare before/after when a task is "raise coverage of X".

## Common pitfalls

From the root `AGENTS.md` "Anti-Patterns" list — these are the ones specs most often miss:

- **Forgetting `.active`** — querying a soft-deletable model without `.active` includes deleted rows. Test that deletion actually hides records.
- **Direct state assignment** — never `task.state = "done"`; use `state_machine.transition_to!`. A spec that sets state directly tests nothing about the machine.
- **Writing `cached_*` columns directly** — they are denormalized; assert them via the EstimateCacheable callbacks, never set them.
- **Skipping `update_context`** in Turbo Stream form params — controllers select the partial from it; a request spec that omits it exercises the wrong branch.
- **Hard-coded timezone** — assert through the org timezone / `format_in_timezone`, not a literal offset.
- **Unconfirmed users** — always build users via the `:user` factory so Devise confirmation is satisfied before `sign_in`.
- **`verify_partial_doubles`** will surface stubs against renamed/removed methods — fix the stub, don't disable it.

## Additional resources

### References (load when relevant)

- `references/conventions.md` — UserPartyRole hierarchy walkthrough, factory catalog, naming, subject-vs-let, stubbing, and the timezone rules.
- `references/statesman-and-papertrail.md` — Statesman transition testing and PaperTrail audit patterns.
- `references/authorization.md` — Devise `sign_in` + Pundit policy and Scope testing.
- `references/coverage-targets.md` — prioritized list of what to test next and what not to chase.

### Examples (copy and adapt)

- `examples/model_spec.rb` — validations, associations, soft delete, estimate-cache rollup.
- `examples/state_machine_spec.rb` — Statesman transitions, guards, propagation, atomicity.
- `examples/policy_spec.rb` — Pundit policy actions + Scope resolution via UserPartyRole.
- `examples/request_spec.rb` — Devise `sign_in` + authorization at the HTTP layer.
- `examples/service_spec.rb` — PORO service object.
- `examples/tool_spec.rb` — MCP tool with `.active` scoping + PaperTrail.
- `examples/component_spec.rb` — ViewComponent with `render_inline` + Capybara + policy stub.
- `examples/helper_spec.rb` — view helper.
- `examples/mailer_spec.rb` — ActionMailer assertions.
- `examples/job_spec.rb` — ActiveJob / Solid Queue enqueue + perform.
- `examples/factory.rb` — factory with traits, transient attributes, and a callback.

### Scripts

- `scripts/run-coverage.sh` — Docker-aware suite runner that prints SimpleCov %.

## Verification — always run before returning

After writing or modifying a spec, **you must run it and confirm it is green before finishing**.

### Which command to run

- **Changed only the target spec file** — run that file alone:
  ```bash
  docker compose exec rails bash -lc "bundle exec rspec <spec_path>"
  ```
- **Changed any other file inside `spec/`** (support files, factories) — run the full suite:
  ```bash
  docker compose exec rails bash -lc "bundle exec rspec"
  ```

> All spec-writing changes are restricted to the `spec/` folder. Never edit application code (`app/`, `config/`, etc.) to make a test pass; mark the example `xit` with a comment explaining the blocker instead.

### On failure

- Fix the spec (not the application code) and re-run.
- If a test reveals a genuine model/application bug that cannot be fixed in the spec, mark it `xit` with a comment: `# xit: model bug — <short description>`.
- Do not return until the run shows **0 failures**.
