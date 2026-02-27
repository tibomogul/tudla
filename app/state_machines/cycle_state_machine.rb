# app/state_machines/cycle_state_machine.rb
class CycleStateMachine
  include Statesman::Machine

  state :shaping, initial: true
  state :betting
  state :active
  state :completed

  transition from: :shaping, to: [ :betting ]
  transition from: :betting, to: [ :active ]
  transition from: :active, to: [ :completed ]

  after_transition(after_commit: true) do |model, transition|
    model.status = transition.to_state
    model.save!
  end

  # Circuit breaker: log unfinished projects when cycle completes
  after_transition(to: :completed, after_commit: true) do |model, transition|
    unfinished = model.unfinished_projects
    if unfinished.any?
      Rails.logger.info(
        "Circuit breaker: Cycle ##{model.id} '#{model.name}' completed with " \
        "#{unfinished.count} unfinished project(s): #{unfinished.pluck(:id).join(', ')}"
      )
    end
  end
end
