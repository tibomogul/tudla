# frozen_string_literal: true

require "rails_helper"

RSpec.describe ListPitchesTool, type: :model do
  let(:organization) { create(:organization, name: "Test Org") }
  let(:user) do
    create(:user, email: "testuser@example.com", username: "testuser", confirmation_token: "token_lp1").tap do |u|
      UserPartyRole.create!(user: u, party: organization, role: "member")
    end
  end
  let(:other_user) do
    create(:user, email: "otheruser@example.com", username: "otheruser", confirmation_token: "token_lp2")
  end

  let(:tool) { described_class.new({ user: user }) }

  describe "#execute" do
    it "returns pitches accessible to current user" do
      pitch = create(:pitch, user: user, organization: organization, status: "ready_for_betting")

      result = tool.execute

      expect(result).to include("pitch(es)")
      expect(result).to include(pitch.id.to_s)
    end

    it "filters by organization_id" do
      other_org = create(:organization, name: "Other Org")
      UserPartyRole.create!(user: user, party: other_org, role: "member")

      pitch1 = create(:pitch, user: user, organization: organization, status: "ready_for_betting")
      pitch2 = create(:pitch, user: user, organization: other_org, status: "ready_for_betting")

      result = tool.execute(organization_id: organization.id)

      expect(result).to include(pitch1.id.to_s)
      expect(result).not_to include("ID: #{pitch2.id}")
    end

    it "filters by status" do
      pitch1 = create(:pitch, user: user, organization: organization, status: "ready_for_betting")
      pitch2 = create(:pitch, user: user, organization: organization, status: "draft")

      result = tool.execute(status: "ready_for_betting")

      expect(result).to include(pitch1.id.to_s)
      expect(result).not_to include("ID: #{pitch2.id}")
    end

    it "excludes soft-deleted pitches" do
      pitch = create(:pitch, user: user, organization: organization, status: "ready_for_betting")
      pitch.soft_delete

      result = tool.execute

      expect(result).to include("No pitches found.")
    end

    it "respects policy scope - user cannot see drafts from other users" do
      other_member = create(:user, email: "member@example.com", confirmation_token: "token_lp3").tap do |u|
        UserPartyRole.create!(user: u, party: organization, role: "member")
      end
      create(:pitch, user: other_member, organization: organization, status: "draft")

      result = tool.execute

      expect(result).to include("No pitches found.")
    end

    it "respects policy scope - user cannot see pitches from other orgs" do
      other_org = create(:organization, name: "Other Org")
      create(:pitch, user: other_user, organization: other_org, status: "ready_for_betting")

      result = tool.execute

      expect(result).to include("No pitches found.")
    end

    it "respects limit" do
      3.times do
        create(:pitch, user: user, organization: organization, status: "ready_for_betting")
      end

      result = tool.execute(limit: 2)

      expect(result).to include("2 pitch(es)")
    end
  end
end
