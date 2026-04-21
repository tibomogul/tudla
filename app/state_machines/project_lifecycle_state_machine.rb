# app/state_machines/project_lifecycle_state_machine.rb
class ProjectLifecycleStateMachine
  include Statesman::Machine

  state :active, initial: true
  state :done
  state :archived

  transition from: :active,   to: [ :done, :archived ]
  transition from: :done,     to: [ :archived, :active ]
  transition from: :archived, to: [ :active ]

  after_transition(after_commit: true) do |model, transition|
    to_state = transition.to_state
    # Skip the initial auto-transition that Statesman records on first machine
    # materialization — it does not change state and children already default to "active".
    next if to_state == "active" && model.lifecycle_state == "active" && model.done_at.nil? && model.archived_at.nil?

    updates = { lifecycle_state: to_state }
    updates[:done_at]     = Time.current if to_state == "done"
    updates[:archived_at] = Time.current if to_state == "archived"
    model.update_columns(updates)
    model.propagate_lifecycle_to_children!
  end
end
