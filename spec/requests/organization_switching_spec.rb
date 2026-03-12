require "rails_helper"

RSpec.describe "Organization Switching", type: :request do
  let(:org_a) { create(:organization, name: "Org A") }
  let(:org_b) { create(:organization, name: "Org B") }
  let(:user) { create(:user) }

  before do
    UserPartyRole.create!(user: user, party: org_a, role: "admin")
    sign_in(user)
  end

  describe "PATCH /organizations/:id/switch" do
    it "switches to an accessible organization" do
      UserPartyRole.create!(user: user, party: org_b, role: "member")

      patch switch_organization_path(org_b)

      expect(response).to redirect_to(user_root_path)
      follow_redirect!
      expect(response.body).to include("Switched to Org B")
    end

    it "persists the selected organization across requests" do
      UserPartyRole.create!(user: user, party: org_b, role: "member")

      patch switch_organization_path(org_b)
      get teams_url

      expect(response).to be_successful
    end

    it "rejects switching to an inaccessible organization" do
      patch switch_organization_path(org_b)

      expect(response).to redirect_to(user_root_path)
      follow_redirect!
      expect(response.body).to include("Organization not found")
    end

    it "rejects switching to a non-existent organization" do
      patch switch_organization_path(id: 999999)

      expect(response).to redirect_to(user_root_path)
      follow_redirect!
      expect(response.body).to include("Organization not found")
    end
  end

  describe "current_organization" do
    it "defaults to the first accessible organization" do
      get user_root_path

      expect(response).to be_successful
      expect(response.body).to include("Org A")
    end

    it "falls back to first org when session org is no longer accessible" do
      UserPartyRole.create!(user: user, party: org_b, role: "member")

      # Switch to org_b
      patch switch_organization_path(org_b)

      # Remove access to org_b
      UserPartyRole.where(user: user, party: org_b).destroy_all
      user.bust_organizations_cache

      get user_root_path

      expect(response).to be_successful
    end
  end
end
