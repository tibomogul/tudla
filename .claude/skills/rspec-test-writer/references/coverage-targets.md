# What to Test Next

Tudla is already on Rails 8.1 — there is no upgrade to underwrite. The purpose of new specs is to **lock down current behaviour** (especially the cross-cutting concerns that are easy to break silently) and to grow meaningful coverage on the core domain. Chase regressions-prevented per hour, not the raw coverage number.

Run `bash .claude/skills/rspec-test-writer/scripts/run-coverage.sh` for the current percentage before relying on any list here. Open `coverage/index.html` for the per-file breakdown.

## Recommended priority order

Order work so each round buys the most regression protection.

1. **Model concerns (cross-cutting)** — `SoftDeletable`, `EstimateCacheable`, the `*able`/delegated-type containers (Notable/Linkable/Attachable). One spec protects every model that includes the concern. `spec/models/estimate_cacheable_spec.rb` is the model to emulate.
2. **State machines** — `Task`, `Project` lifecycle/risk, `Pitch`, `Cycle`. These encode the rules most likely to be broken by a refactor: guards, forbidden transitions, child propagation, transactional atomicity. `spec/state_machines/project_lifecycle_state_machine_spec.rb` is the reference.
3. **Pundit policies** — actions **and** `Scope.resolve`. Cover the role boundary (admin vs member vs non-member), the hierarchy edges (team-role-only, project-role-only), state-gated permissions, and that scopes exclude soft-deleted/other-org records. `spec/policies/pitch_policy_spec.rb` is the reference.
4. **Domain models** — `Task`, `Scope`, `Project`, `Cycle`, `Pitch`: validations, associations, named scopes (all `.active`-aware), and the small behaviours (`assignable_users`, `organization`, `timezone`, `read_only?`).
5. **Services (POROs)** — pure-ish business logic; easy to test once the factory graph exists. `spec/services/report_ai_assist_service_spec.rb` shows the shape (stub external collaborators).
6. **MCP tools** — every tool query must use `.active` + Pundit. Test inclusion, cross-user/team/org exclusion, and soft-delete exclusion. `spec/tools/list_user_changes_tool_spec.rb` is the (very thorough) reference.
7. **Request specs** — for routing, auth wiring, parameter handling (including `update_context` for Turbo Stream forms), and that the controller calls `authorize`/`policy_scope`. Prefer request specs over controller specs.
8. **ViewComponents** — rendering + policy gating with `render_inline` + Capybara. `spec/components/note_row_component_spec.rb` is the reference.
9. **Helpers / mailers** — last; usually thin. `spec/mailers/organization_mailer_spec.rb` is a good mailer template.

## High-value behaviours to always cover

- **Soft delete**: every scope/policy/tool/service that reads a soft-deletable model needs an "excludes soft-deleted" example.
- **Estimate rollup**: create/update/move/soft-delete/restore/nil — assert parent `cached_*` after reload, never set the columns.
- **Lifecycle propagation**: a project transition must cascade `project_lifecycle_state` and `read_only?` to children, and roll back atomically on failure.
- **Authorization boundaries**: the role/state edge of each policy rule, plus Scope exclusions.
- **Timezone**: org-level timezone display, not the UTC/browser clock.

## What not to chase

- **Generated boilerplate** — `application_cable/*`, default `ApplicationController` scaffolding, route boilerplate. Coverage % here is misleading.
- **Scaffold-generated specs that still contain `skip(...)`/`pending`** (e.g. the default `spec/requests/tasks_spec.rb`) — replace them with real specs rather than padding them to pass.
- **The styling/CSS build** — `app/assets/tailwind/*`, generated `icons.css`. Not unit-testable here.
- **Re-testing the framework** — that `belongs_to` exists, that a column exists. Test behaviour, not Rails.

## Tracking progress

After each batch of new specs:

1. `bash .claude/skills/rspec-test-writer/scripts/run-coverage.sh` — confirm green.
2. Read `coverage/.last_run.json` for the new percentage.
3. Open `coverage/index.html` to pick the next-best file to target.

Meaningfulness is the bar, not a percentage. A green run with real assertions beats a higher number padded by tautologies.
