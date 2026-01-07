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
end
