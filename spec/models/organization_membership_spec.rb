require "rails_helper"

RSpec.describe "Organization membership", type: :model do
  let(:organization) { create(:organization) }
  let(:other_org) { create(:organization) }
  let(:team) { create(:team, organization: organization) }
  let(:other_team) { create(:team, organization: other_org) }
  let(:project) { create(:project, team: team) }
  let(:other_project) { create(:project, team: other_team) }
  let(:user) { create(:user) }

  describe "Organization#member?" do
    context "direct organization role" do
      it "returns true when user has an org-level role" do
        UserPartyRole.create!(user: user, party: organization, role: "admin")

        expect(organization.member?(user)).to be true
      end

      it "returns true for member role" do
        UserPartyRole.create!(user: user, party: organization, role: "member")

        expect(organization.member?(user)).to be true
      end
    end

    context "team role" do
      it "returns true when user has a role on a team in the organization" do
        UserPartyRole.create!(user: user, party: team, role: "member")

        expect(organization.member?(user)).to be true
      end

      it "returns false when user has a role on a team in a different organization" do
        UserPartyRole.create!(user: user, party: other_team, role: "member")

        expect(organization.member?(user)).to be false
      end
    end

    context "project role" do
      it "returns true when user has a role on a project in the organization" do
        UserPartyRole.create!(user: user, party: project, role: "member")

        expect(organization.member?(user)).to be true
      end

      it "returns false when user has a role on a project in a different organization" do
        UserPartyRole.create!(user: user, party: other_project, role: "member")

        expect(organization.member?(user)).to be false
      end
    end

    context "no roles" do
      it "returns false when user has no roles at all" do
        expect(organization.member?(user)).to be false
      end
    end

    context "soft-deleted entities" do
      it "returns false when the team is soft-deleted" do
        UserPartyRole.create!(user: user, party: team, role: "member")
        team.update!(deleted_at: Time.current)

        expect(organization.member?(user)).to be false
      end

      it "returns false when the project is soft-deleted" do
        UserPartyRole.create!(user: user, party: project, role: "member")
        project.update!(deleted_at: Time.current)

        expect(organization.member?(user)).to be false
      end
    end

    context "multiple roles" do
      it "returns true when user has roles at multiple levels" do
        UserPartyRole.create!(user: user, party: organization, role: "admin")
        UserPartyRole.create!(user: user, party: team, role: "member")

        expect(organization.member?(user)).to be true
      end

      it "returns true for org even when user also belongs to another org" do
        UserPartyRole.create!(user: user, party: organization, role: "member")
        UserPartyRole.create!(user: user, party: other_org, role: "admin")

        expect(organization.member?(user)).to be true
        expect(other_org.member?(user)).to be true
      end
    end
  end

  describe "Organization#members" do
    let(:user_a) { create(:user) }
    let(:user_b) { create(:user) }
    let(:user_c) { create(:user) }

    it "returns users with direct org roles" do
      UserPartyRole.create!(user: user_a, party: organization, role: "admin")

      expect(organization.members).to include(user_a)
    end

    it "returns users with team roles" do
      UserPartyRole.create!(user: user_a, party: team, role: "member")

      expect(organization.members).to include(user_a)
    end

    it "returns users with project roles" do
      UserPartyRole.create!(user: user_a, party: project, role: "member")

      expect(organization.members).to include(user_a)
    end

    it "returns users across all hierarchy levels without duplicates" do
      UserPartyRole.create!(user: user_a, party: organization, role: "admin")
      UserPartyRole.create!(user: user_a, party: team, role: "member")

      result = organization.members.to_a
      expect(result.count { |u| u.id == user_a.id }).to eq(1)
    end

    it "excludes users from other organizations" do
      UserPartyRole.create!(user: user_a, party: organization, role: "admin")
      UserPartyRole.create!(user: user_b, party: other_org, role: "admin")

      members = organization.members
      expect(members).to include(user_a)
      expect(members).not_to include(user_b)
    end

    it "excludes soft-deleted users" do
      UserPartyRole.create!(user: user_a, party: organization, role: "admin")
      UserPartyRole.create!(user: user_b, party: organization, role: "member")
      user_b.update!(deleted_at: Time.current)

      expect(organization.members).to include(user_a)
      expect(organization.members).not_to include(user_b)
    end

    it "returns an empty relation when no users have roles" do
      expect(organization.members).to be_empty
    end

    it "returns users from all hierarchy levels" do
      UserPartyRole.create!(user: user_a, party: organization, role: "admin")
      UserPartyRole.create!(user: user_b, party: team, role: "member")
      UserPartyRole.create!(user: user_c, party: project, role: "member")

      members = organization.members
      expect(members).to include(user_a, user_b, user_c)
    end
  end

  describe "Organization#hierarchy_roles" do
    let(:user_a) { create(:user) }
    let(:user_b) { create(:user) }

    it "returns an ActiveRecord relation" do
      expect(organization.hierarchy_roles).to be_a(ActiveRecord::Relation)
    end

    it "includes roles at the organization level" do
      role = UserPartyRole.create!(user: user_a, party: organization, role: "admin")

      expect(organization.hierarchy_roles).to include(role)
    end

    it "includes roles at the team level" do
      role = UserPartyRole.create!(user: user_a, party: team, role: "member")

      expect(organization.hierarchy_roles).to include(role)
    end

    it "includes roles at the project level" do
      role = UserPartyRole.create!(user: user_a, party: project, role: "member")

      expect(organization.hierarchy_roles).to include(role)
    end

    it "excludes roles from other organizations" do
      UserPartyRole.create!(user: user_a, party: organization, role: "admin")
      other_role = UserPartyRole.create!(user: user_b, party: other_org, role: "admin")

      expect(organization.hierarchy_roles).not_to include(other_role)
    end

    it "excludes roles on soft-deleted teams" do
      role = UserPartyRole.create!(user: user_a, party: team, role: "member")
      team.update!(deleted_at: Time.current)

      expect(organization.hierarchy_roles).not_to include(role)
    end

    it "excludes roles on soft-deleted projects" do
      role = UserPartyRole.create!(user: user_a, party: project, role: "member")
      project.update!(deleted_at: Time.current)

      expect(organization.hierarchy_roles).not_to include(role)
    end

    it "is chainable with additional where clauses" do
      UserPartyRole.create!(user: user_a, party: organization, role: "admin")
      UserPartyRole.create!(user: user_b, party: team, role: "member")

      result = organization.hierarchy_roles.where(user: user_a)
      expect(result.count).to eq(1)
    end

    it "works with a pre-computed hierarchy hash" do
      role = UserPartyRole.create!(user: user_a, party: team, role: "member")
      hierarchy = organization.hierarchy_ids

      expect(organization.hierarchy_roles(hierarchy: hierarchy)).to include(role)
    end

    it "returns only org-level roles when there are no teams" do
      org_without_teams = create(:organization)
      role = UserPartyRole.create!(user: user_a, party: org_without_teams, role: "admin")

      result = org_without_teams.hierarchy_roles
      expect(result).to include(role)
      expect(result.count).to eq(1)
    end
  end

  describe "Organization#hierarchy_ids" do
    it "returns the organization id" do
      expect(organization.hierarchy_ids[:org_id]).to eq(organization.id)
    end

    it "returns active team ids as a set" do
      team # create
      ids = organization.hierarchy_ids[:team_ids]

      expect(ids).to be_a(Set)
      expect(ids).to include(team.id)
    end

    it "returns active project ids as a set" do
      project # create
      ids = organization.hierarchy_ids[:project_ids]

      expect(ids).to be_a(Set)
      expect(ids).to include(project.id)
    end

    it "excludes soft-deleted teams" do
      team.update!(deleted_at: Time.current)

      expect(organization.hierarchy_ids[:team_ids]).not_to include(team.id)
    end

    it "excludes soft-deleted projects" do
      project.update!(deleted_at: Time.current)

      expect(organization.hierarchy_ids[:project_ids]).not_to include(project.id)
    end

    it "excludes projects on soft-deleted teams" do
      project # create first
      team.update!(deleted_at: Time.current)

      expect(organization.hierarchy_ids[:project_ids]).not_to include(project.id)
    end

    it "does not include entities from other organizations" do
      other_team # create
      other_project # create

      hierarchy = organization.hierarchy_ids
      expect(hierarchy[:team_ids]).not_to include(other_team.id)
      expect(hierarchy[:project_ids]).not_to include(other_project.id)
    end
  end
end
