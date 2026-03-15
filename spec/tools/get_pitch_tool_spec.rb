# frozen_string_literal: true

require "rails_helper"

RSpec.describe GetPitchTool, type: :model do
  let(:organization) { create(:organization, name: "Test Org") }
  let(:team) { create(:team, name: "Test Team", organization: organization) }
  let(:user) do
    create(:user, email: "testuser@example.com", username: "testuser", confirmation_token: "token_gp1").tap do |u|
      UserPartyRole.create!(user: u, party: organization, role: "member")
    end
  end

  let(:tool) { described_class.new({ user: user }) }

  describe "#execute" do
    it "returns pitch details with all ingredients" do
      pitch = create(:pitch, user: user, organization: organization, status: "ready_for_betting",
        problem: "The problem", solution: "The solution", rabbit_holes: "Watch out", no_gos: "Don't do this")

      result = tool.execute(pitch_id: pitch.id)

      expect(result).to include(pitch.id.to_s)
      expect(result).to include(pitch.title)
      expect(result).to include("The problem")
      expect(result).to include("The solution")
      expect(result).to include("Watch out")
      expect(result).to include("Don't do this")
    end

    it "shows linked projects" do
      pitch = create(:pitch, user: user, organization: organization, status: "bet")
      project = create(:project, name: "Linked Project", team: team, pitch: pitch)

      result = tool.execute(pitch_id: pitch.id)

      expect(result).to include("Linked Projects")
      expect(result).to include(project.name)
    end

    it "raises error when pitch not found" do
      expect { tool.execute(pitch_id: -1) }.to raise_error(RuntimeError, /Pitch not found/)
    end

    it "raises error when pitch not accessible via policy scope" do
      other_org = create(:organization, name: "Other Org")
      other_user = create(:user, email: "otheruser@example.com", confirmation_token: "token_gp2")
      pitch = create(:pitch, user: other_user, organization: other_org, status: "ready_for_betting")

      expect { tool.execute(pitch_id: pitch.id) }.to raise_error(RuntimeError, /Pitch not found/)
    end

    it "excludes soft-deleted pitches" do
      pitch = create(:pitch, user: user, organization: organization, status: "ready_for_betting")
      pitch.soft_delete

      expect { tool.execute(pitch_id: pitch.id) }.to raise_error(RuntimeError, /Pitch not found/)
    end
  end
end
