# app/state_machines/task_state_machine.rb
class TaskStateMachine
  include Statesman::Machine
  extend PulseTransitionPublishing

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

  # Publish task.transitioned to subscribers; PulseRecipientResolver
  # additionally notifies project admins when a task lands in_review.
  publishes_pulse_transitions action: "task.transitioned",
    initial: "new", transitions: :task_transitions
end
