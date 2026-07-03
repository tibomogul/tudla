# Shared Pulse publishing for Statesman state machines. Host-owned (it knows
# User and the host's transition-table conventions) so the Pulse:: core stays
# extractable.
module PulseTransitionPublishing
  # Installs an after-commit hook that publishes `action` with from/to state
  # metadata. Published "safely": the transition is already persisted, so a
  # publish failure is logged, never raised out of transition_to!.
  #
  #   extend PulseTransitionPublishing
  #   publishes_pulse_transitions action: "task.transitioned",
  #     initial: "new", transitions: :task_transitions
  #
  # For a publish that must stay inside the transition's transaction (outbox
  # semantics), call PulseTransitionPublishing.publish_transition directly
  # from a synchronous after_transition block with safely: false.
  def publishes_pulse_transitions(action:, initial:, transitions:)
    after_transition(after_commit: true) do |model, transition|
      PulseTransitionPublishing.publish_transition(model, transition,
        action: action, initial: initial, transitions: transitions)
    end
  end

  def self.publish_transition(model, transition, action:, initial:, transitions:, safely: true)
    previous = model.public_send(transitions)
      .where("sort_key < ?", transition.sort_key)
      .order(:sort_key).last
    from_state = previous&.to_state || initial
    # Skip the machine's initial self-transition (e.g. new→new) — the
    # <prefix>.created event already covers record creation.
    return if from_state == transition.to_state.to_s

    # The actor comes from the transition metadata (controllers and MCP tools
    # pass user_id), with Pulse::Current as fallback when absent.
    actor = User.active.find_by(id: transition.metadata["user_id"]) if transition.metadata["user_id"]

    model.public_send(safely ? :publish_pulse_event_safely : :publish_pulse_event,
      action,
      metadata: {
        "from_state" => from_state,
        "to_state" => transition.to_state
      },
      **(actor ? { user: actor } : {}))
  end
end
