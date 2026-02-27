# app/state_machines/pitch_state_machine.rb
class PitchStateMachine
  include Statesman::Machine

  state :draft, initial: true
  state :ready_for_betting
  state :bet
  state :rejected

  transition from: :draft, to: [ :ready_for_betting ]
  transition from: :ready_for_betting, to: [ :bet, :rejected ]
  transition from: :rejected, to: [ :draft ] # allow rework

  after_transition(after_commit: true) do |model, transition|
    model.status = transition.to_state
    model.save!
  end
end
