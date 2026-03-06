require "rails_helper"

RSpec.describe PitchTransition, type: :model do
  let(:user) { create(:user) }
  let(:organization) { create(:organization) }
  let(:pitch) { create(:pitch, user: user, organization: organization) }

  describe "associations" do
    it "belongs to pitch" do
      pitch.state_machine.transition_to!(:ready_for_betting)
      transition = pitch.pitch_transitions.last
      expect(transition.pitch).to eq(pitch)
    end
  end

  describe "transition creation" do
    it "creates transition records" do
      # Statesman creates an initial transition to :draft, then our explicit one
      expect {
        pitch.state_machine.transition_to!(:ready_for_betting)
      }.to change(PitchTransition, :count)
      expect(pitch.pitch_transitions.count).to be >= 1
    end

    it "stores the correct to_state" do
      pitch.state_machine.transition_to!(:ready_for_betting)
      transition = pitch.pitch_transitions.order(:sort_key).last
      expect(transition.to_state).to eq("ready_for_betting")
    end

    it "stores metadata" do
      pitch.state_machine.transition_to!(:ready_for_betting, user_id: user.id)
      transition = pitch.pitch_transitions.order(:sort_key).last
      expect(transition.metadata["user_id"]).to eq(user.id)
    end

    it "tracks most_recent flag" do
      pitch.state_machine.transition_to!(:ready_for_betting)
      pitch.state_machine.transition_to!(:rejected)

      transitions = pitch.pitch_transitions.order(:sort_key)
      expect(transitions.last.most_recent).to be true
      expect(transitions.first.most_recent).to be false
    end
  end
end
