# app/state_machines/task_state_machine.rb
class TaskStateMachine
  include Statesman::Machine

  state :new, initial: true
  state :in_progress
  state :in_review
  state :done
  state :blocked

  transition from: :new,         to: [ :in_progress ]
  transition from: :in_progress, to: [ :in_review, :blocked ]
  transition from: :in_review,   to: [ :done, :blocked ]
  transition from: :blocked,     to: [ :in_progress ]
  transition from: :done,        to: [ :in_review ] # for reopen

  guard_transition(to: :in_progress) do |task, transition|
    task.responsible_user.present? &&
      task.unassisted_estimate.present? &&
      task.ai_assisted_estimate.present?
  end

  after_transition(after_commit: true) do |model, transition|
    model.state = transition.to_state
    model.save!
  end

  # Publish task.transitioned to subscribers. The actor comes from the
  # transition metadata (controllers and MCP tools pass user_id) with
  # Pulse::Current as fallback; PulseRecipientResolver additionally notifies
  # project admins when a task lands in_review. Published "safely": this runs
  # after commit, so the transition is already persisted and a publish failure
  # must not raise out of transition_to!.
  after_transition(after_commit: true) do |model, transition|
    previous = model.task_transitions
      .where("sort_key < ?", transition.sort_key)
      .order(:sort_key).last
    from_state = previous&.to_state || "new"
    # Skip the machine's initial new→new transition — task.created covers it.
    next if from_state == transition.to_state.to_s

    actor = User.find_by(id: transition.metadata["user_id"]) if transition.metadata["user_id"]

    model.publish_pulse_event_safely("task.transitioned",
      metadata: {
        "from_state" => from_state,
        "to_state" => transition.to_state
      },
      **(actor ? { user: actor } : {}))
  end
end
