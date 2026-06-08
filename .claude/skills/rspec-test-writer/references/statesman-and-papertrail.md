# Statesman and PaperTrail Testing

Load this when writing specs for any model with a Statesman machine (`Task`, `Project` lifecycle/risk, `Pitch`, `Cycle`) or any model that needs PaperTrail audit assertions.

## Statesman: the machines

Each machine is a plain class in `app/state_machines/` that `include Statesman::Machine`, declares `state ...`, `transition from: ..., to: [...]`, optional `guard_transition`, and `after_transition`. The model exposes the machine through a memoized method:

```ruby
# Task
task.state_machine                      # => TaskStateMachine
task.current_state                      # "new" | "in_progress" | ...
task.state_machine.transition_to!(:in_progress, user_id: user.id)
task.state_machine.can_transition_to?(:in_progress)   # => true/false
Task.in_state(:new)                     # Statesman ActiveRecord query adapter
Task.not_in_state(:done)
```

`Project` has **two** machines: `project.lifecycle_state_machine` (active/done/archived) and the risk machine (green/yellow/red). Name them precisely in specs.

**Never assign state directly** (`task.state = "done"`). A spec that does so tests nothing about the machine and violates the codebase's core rule.

## Test these dimensions for each machine

### 1. Initial state

```ruby
it "starts in new" do
  expect(task.current_state).to eq("new")
end
```

### 2. Each allowed transition + side effects

```ruby
it "allows active -> done" do
  project.lifecycle_state_machine.transition_to!(:done)
  expect(project.reload.lifecycle_state).to eq("done")
  expect(project).to be_done
  expect(project.done_at).to be_present
  expect(project).to be_read_only
end
```

Note `transition_to!` persists; `reload` to read the column the `after_transition(after_commit: true)` callback wrote.

### 3. Forbidden transitions raise

Statesman raises `Statesman::TransitionFailedError` for a disallowed transition, and `Statesman::GuardFailedError` when a guard blocks an otherwise-valid one:

```ruby
it "forbids archived -> done (must reopen first)" do
  project.lifecycle_state_machine.transition_to!(:archived)
  expect {
    project.lifecycle_state_machine.transition_to!(:done)
  }.to raise_error(Statesman::TransitionFailedError)
end
```

### 4. Guards — exercise both branches

`TaskStateMachine` guards entry to `:in_progress`:

```ruby
guard_transition(to: :in_progress) do |task, _transition|
  task.responsible_user.present? &&
    task.unassisted_estimate.present? &&
    task.ai_assisted_estimate.present?
end
```

Test the guard satisfied (transition succeeds) and each missing precondition (transition blocked):

```ruby
context "when responsible_user and both estimates are set" do
  let(:task) { create(:task, project: project, responsible_user: user, unassisted_estimate: 5, ai_assisted_estimate: 3) }
  it { expect(task.state_machine.can_transition_to?(:in_progress)).to be true }
end

context "when an estimate is missing" do
  let(:task) { create(:task, project: project, responsible_user: user, unassisted_estimate: nil, ai_assisted_estimate: 3) }
  it "is blocked by the guard" do
    expect(task.state_machine.can_transition_to?(:in_progress)).to be false
    expect { task.state_machine.transition_to!(:in_progress) }
      .to raise_error(Statesman::GuardFailedError)
  end
end
```

### 5. after_transition side effects — assert the effect, not the call

`ProjectLifecycleStateMachine` propagates the new lifecycle state to every child scope and task in a single bulk UPDATE per table. Lock the behaviour down by asserting the children, not by expecting an internal method:

```ruby
it "bulk-updates scopes and tasks on transition to done" do
  project.lifecycle_state_machine.transition_to!(:done)
  expect(scope.reload.project_lifecycle_state).to eq("done")
  expect(task.reload.project_lifecycle_state).to eq("done")
  expect(task.reload).to be_read_only
end
```

### 6. Metadata

Transitions accept a metadata hash persisted on the transition row — Tudla stores `user_id`:

```ruby
task.state_machine.transition_to!(:in_progress, user_id: user.id)
last = task.task_transitions.order(:sort_key).last
expect(last.metadata["user_id"]).to eq(user.id)
```

### 7. Transactional atomicity

Synchronous propagation runs inside Statesman's transaction, so a failure mid-propagation rolls back the transition row too. The lifecycle spec proves this by stubbing the propagation to raise and asserting nothing changed:

```ruby
allow(project).to receive(:propagate_lifecycle_to_children!).and_raise(ActiveRecord::StatementInvalid, "boom")
expect { project.lifecycle_state_machine.transition_to!(:archived) }
  .to raise_error(ActiveRecord::StatementInvalid)
expect(project.reload.lifecycle_state).to eq("active")
```

Worked example: `examples/state_machine_spec.rb`. The shipped `spec/state_machines/project_lifecycle_state_machine_spec.rb` is the reference implementation — read it before writing a new machine spec.

---

# PaperTrail

## Enabling versioning in a spec

PaperTrail is declared per model with `has_paper_trail` (often with `skip:` columns — e.g. `Task` skips position/`in_today` columns). Two enabling patterns are in use:

### Block form — one change, specific whodunnit

```ruby
PaperTrail.request(whodunnit: other.id) do
  note.update!(content: "edited body")
end
expect(note.versions.last.whodunnit).to eq(other.id.to_s)
```

### Enable/disable toggle — a whole example group

```ruby
before do
  @paper_trail_was_enabled = PaperTrail.enabled?
  PaperTrail.enabled = true
end
after { PaperTrail.enabled = @paper_trail_was_enabled }

it "records the actor" do
  PaperTrail.request.whodunnit = user.id.to_s
  task.update!(name: "Renamed")
  expect(task.versions.last.whodunnit).to eq(user.id.to_s)
end
```

**Restore the prior value** in the `after` — capture `PaperTrail.enabled?` in the `before` and set it back, rather than hardcoding `PaperTrail.enabled = false`. PaperTrail is enabled by default in the test env, so forcing it off in teardown disables versioning for whatever spec runs next under random order (this exact leak broke `note_spec`/`user_party_role_spec` once random ordering was turned on).

## What to assert

- `record.versions.count` change across an action.
- `record.versions.last.event` — `"create"`, `"update"`, or `"destroy"`.
- `record.versions.last.whodunnit` — the actor's `id.to_s`.
- `record.versions.last.changeset` — the actual diff (respecting the model's `skip:` list).

## What not to assert

Do not assert that every model has PaperTrail enabled. A missing `has_paper_trail` is the correct state when a model was never meant to be audited. Also account for `skip:` columns — a change limited to skipped columns produces no version.
