# Tudla Test Conventions — Detailed Reference

This document expands the conventions summarized in `SKILL.md`. Load it when a spec touches the UserPartyRole access hierarchy, soft delete, estimate caching, or timezone-sensitive code.

## 1. The UserPartyRole access pattern

Tudla's domain is a strict containment hierarchy:

```
Organization
   └── Team
         └── Project
               └── Scope
                     └── Task
```

Access is **not** modeled on the records themselves; it is a separate polymorphic join, `UserPartyRole`:

```
UserPartyRole
  user_id  → User
  party    → polymorphic (Organization | Team | Project)
  role     → "admin" | "member"
```

Granting access in a spec is one line per grant:

```ruby
UserPartyRole.create!(user: user, party: organization, role: "admin")
UserPartyRole.create!(user: user, party: team,         role: "member")
UserPartyRole.create!(user: user, party: project,      role: "member")
```

### Resolution is downward, never upward

- A role on an **Organization** grants access to that org's Teams and Projects (and their Scopes/Tasks).
- A role on a **Team** grants access to that team's Projects.
- A role **only on a Project** does **not** grant access to the parent Team or Organization, and does not (for example) let the user see organization-level Pitches.

The policy specs encode exactly these edges. From `spec/policies/pitch_policy_spec.rb`:

```ruby
it "allows a user who only holds a team role in the org to see a pitch" do
  team_member = create(:user)
  team = create(:team, organization: organization)
  UserPartyRole.create!(user: team_member, party: team, role: "member")
  expect(described_class.new(team_member, draft_pitch).show?).to be true
end

it "prevents a user who only holds a project role from seeing a pitch" do
  project_member = create(:user)
  team = create(:team, organization: organization)
  project = create(:project, team: team)
  UserPartyRole.create!(user: project_member, party: project, role: "member")
  expect(described_class.new(project_member, draft_pitch).show?).to be false
end
```

### Membership caching

`User` memoizes its accessible/member organizations. If a spec mutates memberships **after** the user has been touched (e.g. deleting a `UserPartyRole` with `delete_all` to bypass the prune callback), call `user.bust_organizations_cache` before asserting the policy result. See the "co-author who has lost org membership" group in `pitch_policy_spec.rb`.

### When you need the full graph

A `Task` is only meaningful inside `Project → Team → Organization`. Build the graph top-down with explicit associations:

```ruby
let(:organization) { create(:organization) }
let(:team)         { create(:team, organization: organization) }
let(:project)      { create(:project, team: team) }
let(:scope)        { create(:scope, project: project) }
let(:task)         { create(:task, project: project, scope: scope) }
```

`task.organization` walks `project.team.organization`, and `task.timezone` reads `organization.timezone || "Australia/Brisbane"`, so omitting the team/org leaves those nil.

## 2. Factories catalog

Factories live in `spec/factories/<singular>.rb`. Current set: `user`, `organization`, `team`, `project`, `scope`, `task`, `cycle`, `pitch`, `report`, `reportable`, `attachment`, `user_party_role`.

Each defines a **minimal valid record**. Key ones:

- **`user`** — pre-confirmed for Devise (`confirmed_at`, `confirmation_sent_at`, sequenced `confirmation_token`). Never sign in a user that skipped these.
- **`task` / `project` / `scope`** — literal `name`/`description`; pass `project:`/`scope:`/estimate fields at call time.
- **`user_party_role`** — the trait template (`:org_admin`, `:org_member`, `:team_admin`, `:team_member`) with `association :party, factory: :organization`.

### Adding a factory

1. Create `spec/factories/<singular>.rb` with `FactoryBot.define { factory :name do ... end }`.
2. Block form for every attribute. `sequence` for anything that must be unique.
3. Provide associations as bare references (`user`, `project`) and let callers override.
4. Add traits rather than parallel factories.

## 3. Naming and structure

- Spec path mirrors source path: `app/models/scope.rb` → `spec/models/scope_spec.rb`.
- One top-level `RSpec.describe ClassName, type: :symbol`. Set `type:` explicitly — inference is off.
- `describe "#instance_method"` / `describe ".class_method"` for behaviour; `context "when ..."` / `context "with ..."` to vary inputs.
- `it "does the thing"` — present tense, no "should".
- One logical behaviour per `it`; multiple `expect`s are fine when they describe that behaviour.

## 4. Subject vs. let

```ruby
RSpec.describe Task, type: :model do
  subject(:task) { build(:task, project: project) }

  it { is_expected.to be_valid }
end
```

- `subject(:name)` names the implicit subject; prefer it when one object dominates the spec.
- `let(:thing)` for collaborators and inputs.
- `let!(:thing)` only when materialization order matters (counting rows, or the record must exist before the example body).

## 5. Stubbing and mocking

- `allow(obj).to receive(:method).and_return(value)` — partial double.
- `expect(obj).to receive(:method)` — message expectation; fails if not called.
- `instance_double(Klass, method: value)` — verifying double. The component specs use this to stub Pundit policies (`instance_double(NotePolicy, edit?: true, destroy?: false)`).
- `verify_partial_doubles = true` is global — even plain stubs verify against the real interface. Stub collaborators (mailers, jobs, external HTTP, `ActionCable`), never the system under test.

## 6. Time and timezone

- `Time.zone.local(2026, 1, 15, 9, 0)` — preferred over `Time.new` (respects Rails timezone).
- `Date.new(2026, 1, 15)` — explicit pinned dates.
- `travel_to` (already included via `ActiveSupport::Testing::TimeHelpers`) to freeze time.

### Organization-level timezone

Tudla's timezone lives on `Organization` (default `"Australia/Brisbane"`), surfaced through `format_in_timezone(datetime, format)`. Models like `Task` derive it via `organization&.timezone || "Australia/Brisbane"`.

Rules:

1. When asserting a **formatted** time string, compare against the value produced through `format_in_timezone` (or `datetime.in_time_zone(org.timezone)`), not against a UTC/browser-clock format.
2. When a test needs a deterministic "now", wrap it in `travel_to` so both the production code and the assertion see the same instant.
3. Do not assert against a bare `Date.today`/`Time.now` that the wall clock can advance past between the code running and the assertion — a frozen clock makes the spec both deterministic and sensitive to a regression that hard-codes the wrong date.
4. To exercise a non-default org timezone, set it on the organization in the spec and assert the display flips accordingly.

## 7. Soft delete in queries

Because there is no `default_scope`, an unscoped query returns deleted rows. Any spec for a scope/policy/tool/service that reads a soft-deletable model should include a "excludes soft-deleted" example:

```ruby
deleted = create(:task, project: project)
deleted.soft_delete
expect(described_subject).not_to include(deleted)
```

`SoftDeletable` provides `scope :active`, `#soft_delete`, `#restore`, and overrides `#destroy` to soft-delete. **Beware the callback difference:** bare `#soft_delete`/`#restore` use `update_column` and skip callbacks; `EstimateCacheable` re-overrides `#destroy`/`#restore` to also recalc the `cached_*` columns. So assert `.active` exclusion with `#soft_delete`, but assert estimate-cache rollups with `#destroy`/`#restore` (this is why `spec/models/estimate_cacheable_spec.rb` uses `task.destroy`).

## 8. What is out of scope

- No shared examples, custom matchers, or system/feature (Capybara JS) specs exist yet. If a gap is genuinely a browser-integration concern, flag it back to the user rather than inventing a system-spec harness.
- Do not add lookup fixtures — the codebase is factory-only.
