require 'rails_helper'

RSpec.describe "Organization UserPartyRoles", type: :request do
  let(:organization) { create(:organization) }
  let(:admin_user) { create(:user) }
  let(:target_user) { create(:user) }

  before do
    UserPartyRole.create!(user: admin_user, party: organization, role: "admin")
    UserPartyRole.create!(user: target_user, party: organization, role: "member")
    sign_in(admin_user)
  end

  describe "POST /organizations/:id/user_party_roles" do
    it "creates a team role for a user" do
      team = create(:team, organization: organization)
      post organization_user_party_roles_url(organization),
           params: { user_id: target_user.id, party_type: "Team", party_id: team.id, role: "admin" }

      expect(UserPartyRole.exists?(user: target_user, party: team, role: "admin")).to be true
    end

    it "creates a project role for a user" do
      team = create(:team, organization: organization)
      project = create(:project, team: team)
      post organization_user_party_roles_url(organization),
           params: { user_id: target_user.id, party_type: "Project", party_id: project.id, role: "member" }

      expect(UserPartyRole.exists?(user: target_user, party: project, role: "member")).to be true
    end

    it "updates the existing role when party matches but role differs" do
      team = create(:team, organization: organization)
      existing_role = UserPartyRole.create!(user: target_user, party: team, role: "member")

      expect {
        post organization_user_party_roles_url(organization),
             params: { user_id: target_user.id, party_type: "Team", party_id: team.id, role: "admin" }
      }.not_to change(UserPartyRole, :count)

      expect(existing_role.reload.role).to eq("admin")
    end

    it "rejects when user already has the same party and role" do
      team = create(:team, organization: organization)
      UserPartyRole.create!(user: target_user, party: team, role: "member")

      expect {
        post organization_user_party_roles_url(organization),
             params: { user_id: target_user.id, party_type: "Team", party_id: team.id, role: "member" }
      }.not_to change(UserPartyRole, :count)

      expect(response).to redirect_to(organization_users_url(organization))
      expect(flash[:alert]).to include(target_user.email)
      expect(flash[:alert]).to include("member")
    end

    it "rejects roles for teams outside the org" do
      other_org = create(:organization)
      other_team = create(:team, organization: other_org)

      post organization_user_party_roles_url(organization),
           params: { user_id: target_user.id, party_type: "Team", party_id: other_team.id, role: "member" }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /organizations/:id/user_party_roles/:id" do
    it "updates a role from member to admin" do
      team = create(:team, organization: organization)
      role = UserPartyRole.create!(user: target_user, party: team, role: "member")
      patch organization_user_party_role_url(organization, role), params: { role: "admin" }
      expect(role.reload.role).to eq("admin")
    end

    it "rejects updating roles outside the org hierarchy" do
      other_org = create(:organization)
      other_team = create(:team, organization: other_org)
      role = UserPartyRole.create!(user: target_user, party: other_team, role: "member")
      patch organization_user_party_role_url(organization, role), params: { role: "admin" }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /organizations/:id/user_party_roles/:id" do
    it "removes a specific role" do
      team = create(:team, organization: organization)
      role = UserPartyRole.create!(user: target_user, party: team, role: "member")

      delete organization_user_party_role_url(organization, role)
      expect(UserPartyRole.exists?(role.id)).to be false
    end
  end
end
