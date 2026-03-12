require 'rails_helper'

RSpec.describe "Organization Users", type: :request do
  let(:organization) { create(:organization) }
  let(:admin_user) { create(:user) }
  let(:member_user) { create(:user) }

  before do
    UserPartyRole.create!(user: admin_user, party: organization, role: "admin")
    sign_in(admin_user)
  end

  describe "GET /organizations/:id/users" do
    it "renders successfully for org admins" do
      get organization_users_url(organization)
      expect(response).to be_successful
    end

    it "lists users in the organization hierarchy" do
      UserPartyRole.create!(user: member_user, party: organization, role: "member")
      get organization_users_url(organization)
      expect(response.body).to include(member_user.email)
    end

    it "does not list users outside the organization" do
      other_user = create(:user)
      get organization_users_url(organization)
      expect(response.body).not_to include(other_user.email)
    end

    context "add role modal" do
      it "renders the existing role keys data attribute for each user" do
        team = create(:team, organization: organization)
        UserPartyRole.create!(user: member_user, party: organization, role: "member")
        UserPartyRole.create!(user: member_user, party: team, role: "admin")

        get organization_users_url(organization)

        expect(response.body).to include("Organization-#{organization.id}-member")
        expect(response.body).to include("Team-#{team.id}-admin")
      end

      it "does not include roles from other organizations in the data attribute" do
        other_org = create(:organization)
        UserPartyRole.create!(user: member_user, party: organization, role: "member")
        UserPartyRole.create!(user: member_user, party: other_org, role: "admin")

        get organization_users_url(organization)

        expect(response.body).to include("Organization-#{organization.id}-member")
        expect(response.body).not_to include("Organization-#{other_org.id}-admin")
      end
    end

    context "non-admin user" do
      before do
        UserPartyRole.create!(user: member_user, party: organization, role: "member")
        sign_in(member_user)
      end

      it "raises Pundit::NotAuthorizedError" do
        expect {
          get organization_users_url(organization)
        }.to raise_error(Pundit::NotAuthorizedError)
      end
    end

    context "pagination" do
      before do
        22.times do
          u = create(:user)
          UserPartyRole.create!(user: u, party: organization, role: "member")
        end
      end

      it "paginates users with a limit of 20" do
        get organization_users_url(organization)
        expect(response).to be_successful
      end
    end

    context "filtering" do
      it "filters users by email" do
        u = create(:user, email: "findme@example.com")
        UserPartyRole.create!(user: u, party: organization, role: "member")
        get organization_users_url(organization), params: { user_name: "findme" }
        expect(response.body).to include("findme@example.com")
      end
    end
  end

  describe "GET /organizations/:id/users/lookup" do
    it "returns found: false for unknown email" do
      get lookup_organization_users_url(organization), params: { email: "unknown@example.com" }
      json = JSON.parse(response.body)
      expect(json["found"]).to be false
    end

    it "returns found: false for blank email" do
      get lookup_organization_users_url(organization), params: { email: "" }
      json = JSON.parse(response.body)
      expect(json["found"]).to be false
    end

    it "returns found: false when email param is missing" do
      get lookup_organization_users_url(organization)
      json = JSON.parse(response.body)
      expect(json["found"]).to be false
    end

    it "normalizes email case for lookup" do
      existing = create(:user, email: "jane@example.com", username: "jane")
      get lookup_organization_users_url(organization), params: { email: "  JANE@Example.COM  " }
      json = JSON.parse(response.body)
      expect(json["found"]).to be true
      expect(json["username"]).to eq("jane")
    end

    it "returns user info and existing party keys for known email" do
      existing = create(:user, username: "jdoe", preferred_name: "Jane")
      team = create(:team, organization: organization)
      UserPartyRole.create!(user: existing, party: team, role: "member")

      get lookup_organization_users_url(organization), params: { email: existing.email }
      json = JSON.parse(response.body)

      expect(json["found"]).to be true
      expect(json["username"]).to eq("jdoe")
      expect(json["preferred_name"]).to eq("Jane")
      expect(json["existing_party_keys"]).to include("Team-#{team.id}")
    end

    it "returns party keys across the full org hierarchy" do
      existing = create(:user)
      team = create(:team, organization: organization)
      project = create(:project, team: team)
      UserPartyRole.create!(user: existing, party: organization, role: "member")
      UserPartyRole.create!(user: existing, party: team, role: "member")
      UserPartyRole.create!(user: existing, party: project, role: "member")

      get lookup_organization_users_url(organization), params: { email: existing.email }
      json = JSON.parse(response.body)

      expect(json["existing_party_keys"]).to contain_exactly(
        "Organization-#{organization.id}",
        "Team-#{team.id}",
        "Project-#{project.id}"
      )
    end

    it "does not include party keys from other organizations" do
      existing = create(:user)
      other_org = create(:organization)
      other_team = create(:team, organization: other_org)
      UserPartyRole.create!(user: existing, party: other_org, role: "member")
      UserPartyRole.create!(user: existing, party: other_team, role: "admin")

      get lookup_organization_users_url(organization), params: { email: existing.email }
      json = JSON.parse(response.body)

      expect(json["found"]).to be true
      expect(json["existing_party_keys"]).to be_empty
    end

    it "returns empty existing_party_keys for a user with no roles in this org" do
      existing = create(:user)

      get lookup_organization_users_url(organization), params: { email: existing.email }
      json = JSON.parse(response.body)

      expect(json["found"]).to be true
      expect(json["existing_party_keys"]).to eq([])
    end

    it "returns null fields when user has no username or preferred name" do
      existing = create(:user, username: nil, preferred_name: nil)

      get lookup_organization_users_url(organization), params: { email: existing.email }
      json = JSON.parse(response.body)

      expect(json["found"]).to be true
      expect(json["username"]).to be_nil
      expect(json["preferred_name"]).to be_nil
    end

    context "non-admin user" do
      before do
        UserPartyRole.create!(user: member_user, party: organization, role: "member")
        sign_in(member_user)
      end

      it "raises Pundit::NotAuthorizedError" do
        expect {
          get lookup_organization_users_url(organization), params: { email: "test@example.com" }
        }.to raise_error(Pundit::NotAuthorizedError)
      end
    end
  end

  describe "POST /organizations/:id/users" do
    context "new user" do
      it "creates a new user and UserPartyRole" do
        expect {
          post organization_users_url(organization), params: { email: "new@example.com", role: "member" }
        }.to change(User, :count).by(1)
          .and change(UserPartyRole, :count).by(1)

        new_user = User.find_by(email: "new@example.com")
        expect(UserPartyRole.exists?(user: new_user, party: organization)).to be true
        expect(response).to redirect_to(organization_users_url(organization))
      end

      it "passes username and preferred_name to the invited user" do
        post organization_users_url(organization),
             params: { email: "new@example.com", username: "newbie", preferred_name: "New User", role: "member" }

        new_user = User.find_by(email: "new@example.com")
        expect(new_user.username).to eq("newbie")
        expect(new_user.preferred_name).to eq("New User")
      end

      it "does not send OrganizationMailer email for new users" do
        expect {
          post organization_users_url(organization), params: { email: "new@example.com", role: "member" }
        }.not_to have_enqueued_mail(OrganizationMailer, :user_added)
      end

      it "creates the role with the specified role param" do
        post organization_users_url(organization), params: { email: "new@example.com", role: "admin" }
        new_user = User.find_by(email: "new@example.com")
        expect(UserPartyRole.find_by(user: new_user, party: organization).role).to eq("admin")
      end

      it "defaults to member role when role param is absent" do
        post organization_users_url(organization), params: { email: "new@example.com" }
        new_user = User.find_by(email: "new@example.com")
        expect(UserPartyRole.find_by(user: new_user, party: organization).role).to eq("member")
      end

      it "can invite a new user directly to a team" do
        team = create(:team, organization: organization)
        post organization_users_url(organization),
             params: { email: "new@example.com", role: "member", party_type: "Team", party_id: team.id }

        new_user = User.find_by(email: "new@example.com")
        expect(UserPartyRole.exists?(user: new_user, party: team)).to be true
      end

      it "can invite a new user directly to a project" do
        team = create(:team, organization: organization)
        project = create(:project, team: team)
        post organization_users_url(organization),
             params: { email: "new@example.com", role: "member", party_type: "Project", party_id: project.id }

        new_user = User.find_by(email: "new@example.com")
        expect(UserPartyRole.exists?(user: new_user, party: project)).to be true
      end
    end

    context "existing user" do
      let!(:existing) { create(:user) }

      it "does not create a new user" do
        expect {
          post organization_users_url(organization), params: { email: existing.email, role: "member" }
        }.not_to change(User, :count)

        expect(UserPartyRole.exists?(user: existing, party: organization)).to be true
      end

      it "sends notification email" do
        expect {
          post organization_users_url(organization), params: { email: existing.email, role: "member" }
        }.to have_enqueued_mail(OrganizationMailer, :user_added)
      end

      it "sends notification email with correct arguments" do
        expect {
          post organization_users_url(organization), params: { email: existing.email, role: "member" }
        }.to have_enqueued_mail(OrganizationMailer, :user_added).with(
          user: existing, party: organization, added_by: admin_user
        )
      end

      it "adds a user from another organization" do
        other_org = create(:organization)
        UserPartyRole.create!(user: existing, party: other_org, role: "member")

        expect {
          post organization_users_url(organization), params: { email: existing.email, role: "admin" }
        }.to change(UserPartyRole, :count).by(1)
          .and change { UserPartyRole.where(user: existing, party: organization, role: "admin").count }.by(1)

        expect(User.where(email: existing.email).count).to eq(1)
        expect(UserPartyRole.exists?(user: existing, party: other_org, role: "member")).to be true
      end

      it "allows adding an existing org member to a team" do
        UserPartyRole.create!(user: existing, party: organization, role: "member")
        team = create(:team, organization: organization)

        expect {
          post organization_users_url(organization),
               params: { email: existing.email, role: "member", party_type: "Team", party_id: team.id }
        }.to change(UserPartyRole, :count).by(1)

        expect(UserPartyRole.exists?(user: existing, party: team, role: "member")).to be true
      end

      it "allows adding an existing org member to a project" do
        team = create(:team, organization: organization)
        project = create(:project, team: team)
        UserPartyRole.create!(user: existing, party: organization, role: "member")

        expect {
          post organization_users_url(organization),
               params: { email: existing.email, role: "member", party_type: "Project", party_id: project.id }
        }.to change(UserPartyRole, :count).by(1)

        expect(UserPartyRole.exists?(user: existing, party: project, role: "member")).to be true
      end

      it "sends notification email referencing the correct party when adding to a team" do
        team = create(:team, organization: organization)

        expect {
          post organization_users_url(organization),
               params: { email: existing.email, role: "member", party_type: "Team", party_id: team.id }
        }.to have_enqueued_mail(OrganizationMailer, :user_added).with(
          user: existing, party: team, added_by: admin_user
        )
      end

      it "normalizes email case when matching existing user" do
        expect {
          post organization_users_url(organization), params: { email: existing.email.upcase, role: "member" }
        }.not_to change(User, :count)

        expect(UserPartyRole.exists?(user: existing, party: organization)).to be true
      end
    end

    context "duplicate role prevention" do
      let!(:existing) { create(:user) }

      it "rejects when user already has a role for the organization" do
        UserPartyRole.create!(user: existing, party: organization, role: "member")

        expect {
          post organization_users_url(organization), params: { email: existing.email, role: "member" }
        }.not_to change(UserPartyRole, :count)

        expect(response).to redirect_to(new_organization_user_url(organization))
      end

      it "shows alert with party type in message" do
        UserPartyRole.create!(user: existing, party: organization, role: "member")

        post organization_users_url(organization), params: { email: existing.email, role: "member" }

        expect(flash[:alert]).to include(existing.email)
        expect(flash[:alert]).to include("organization")
      end

      it "rejects when user already has a role for the specific team" do
        team = create(:team, organization: organization)
        UserPartyRole.create!(user: existing, party: team, role: "member")

        expect {
          post organization_users_url(organization),
               params: { email: existing.email, role: "admin", party_type: "Team", party_id: team.id }
        }.not_to change(UserPartyRole, :count)

        expect(response).to redirect_to(new_organization_user_url(organization))
      end

      it "does not send email when role already exists" do
        UserPartyRole.create!(user: existing, party: organization, role: "member")

        expect {
          post organization_users_url(organization), params: { email: existing.email, role: "member" }
        }.not_to have_enqueued_mail(OrganizationMailer, :user_added)
      end
    end

    context "validation" do
      it "rejects blank email" do
        post organization_users_url(organization), params: { email: "" }
        expect(response).to redirect_to(organization_users_url(organization))
        expect(flash[:alert]).to eq("Email is required.")
      end

      it "rejects nil email" do
        post organization_users_url(organization), params: {}
        expect(response).to redirect_to(organization_users_url(organization))
        expect(flash[:alert]).to eq("Email is required.")
      end
    end
  end

  describe "PATCH /organizations/:id/users/:user_id/lock" do
    before { UserPartyRole.create!(user: member_user, party: organization, role: "member") }

    it "locks the user account" do
      patch lock_organization_user_url(organization, member_user)
      expect(member_user.reload.access_locked?).to be true
    end

    it "prevents admin from locking themselves" do
      patch lock_organization_user_url(organization, admin_user)
      expect(admin_user.reload.access_locked?).to be false
    end
  end

  describe "PATCH /organizations/:id/users/:user_id/unlock" do
    before do
      UserPartyRole.create!(user: member_user, party: organization, role: "member")
      member_user.lock_access!(send_instructions: false)
    end

    it "unlocks the user account" do
      patch unlock_organization_user_url(organization, member_user)
      expect(member_user.reload.access_locked?).to be false
    end
  end

  describe "DELETE /organizations/:id/users/:user_id" do
    before { UserPartyRole.create!(user: member_user, party: organization, role: "member") }

    it "removes all roles for user in the org hierarchy" do
      team = create(:team, organization: organization)
      UserPartyRole.create!(user: member_user, party: team, role: "member")

      delete organization_user_url(organization, member_user)

      expect(UserPartyRole.where(user: member_user, party: organization)).to be_empty
      expect(UserPartyRole.where(user: member_user, party: team)).to be_empty
    end

    it "locks and soft-deletes the user when they have no other org roles" do
      delete organization_user_url(organization, member_user)

      member_user.reload
      expect(member_user.access_locked?).to be true
      expect(member_user.deleted_at).to be_present
    end

    it "does not lock or soft-delete the user when they belong to another organization" do
      other_org = create(:organization)
      UserPartyRole.create!(user: member_user, party: other_org, role: "member")

      delete organization_user_url(organization, member_user)

      member_user.reload
      expect(member_user.access_locked?).to be false
      expect(member_user.deleted_at).to be_nil
    end

    it "preserves the user record" do
      delete organization_user_url(organization, member_user)

      expect(User.find(member_user.id)).to eq(member_user)
    end

    it "excludes soft-deleted users from the users list" do
      delete organization_user_url(organization, member_user)
      follow_redirect!

      get organization_users_url(organization)
      expect(response.body).not_to include(member_user.email)
    end

    it "prevents removing yourself" do
      delete organization_user_url(organization, admin_user)

      expect(response).to redirect_to(organization_users_url(organization))
      expect(admin_user.reload.deleted_at).to be_nil
    end
  end
end
