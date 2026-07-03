# app/state_machines/project_lifecycle_state_machine.rb
class ProjectLifecycleStateMachine
  include Statesman::Machine

  state :active, initial: true
  state :done
  state :archived

  transition from: :active,   to: [ :done, :archived ]
  transition from: :done,     to: [ :archived, :active ]
  transition from: :archived, to: [ :active ]

  # Synchronous (no after_commit:) so propagation runs inside the same DB
  # transaction as the transition insert. If update_all fails, the transition
  # rolls back and project.lifecycle_state stays consistent with its children.
  after_transition do |model, transition|
    # Skip Statesman's recorded initial transition (the one inserted during
    # machine materialization, not a user-driven transition). At that point
    # this is the only transition row for the project. The project is already
    # "active" by default and children default to "active" — nothing to
    # propagate, and firing here would double the UPDATEs on first machine load.
    next if model.project_lifecycle_transitions.count <= 1 &&
            transition.to_state == "active"

    to_state = transition.to_state
    updates = { lifecycle_state: to_state }
    updates[:done_at]     = Time.current if to_state == "done"
    updates[:archived_at] = Time.current if to_state == "archived"
    model.update_columns(updates)
    model.propagate_lifecycle_to_children!

    # Publish project.transitioned to subscribers. Strict (safely: false):
    # this callback runs inside the transition's transaction, so a publish
    # failure rolls the whole transition back — same outbox semantics as the
    # create/update publishes.
    PulseTransitionPublishing.publish_transition(model, transition,
      action: "project.transitioned", initial: "active",
      transitions: :project_lifecycle_transitions, safely: false)
  end
end
