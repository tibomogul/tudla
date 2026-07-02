# app/state_machines/project_risk_state_machine.rb
class ProjectRiskStateMachine
  include Statesman::Machine

  state :green, initial: true
  state :yellow
  state :red

  transition from: :green,  to: [ :yellow, :red ]
  transition from: :yellow, to: [ :green, :red ]
  transition from: :red,    to: [ :yellow, :green ]

  after_transition(after_commit: true) do |model, transition|
    model.risk_state = transition.to_state
    model.save!
  end

  # Publish project.risk_changed to subscribers. Published "safely": this runs
  # after commit, so the transition is already persisted and a publish failure
  # must not raise out of transition_to!.
  after_transition(after_commit: true) do |model, transition|
    previous = model.project_risk_transitions
      .where("sort_key < ?", transition.sort_key)
      .order(:sort_key).last
    from_state = previous&.to_state || "green"
    # Skip the machine's initial green→green transition.
    next if from_state == transition.to_state.to_s

    actor = User.find_by(id: transition.metadata["user_id"]) if transition.metadata["user_id"]

    model.publish_pulse_event_safely("project.risk_changed",
      metadata: {
        "from_state" => from_state,
        "to_state" => transition.to_state
      },
      **(actor ? { user: actor } : {}))
  end
end
