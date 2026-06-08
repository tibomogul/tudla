# Example: MCP tool spec. Tools inherit from ApplicationTool, are constructed
# with a server-context hash, and invoked via #execute. Every query must use
# .active and Pundit; test inclusion, cross-user/team/org exclusion, and
# soft-delete exclusion.
#
# WHY this shape: mirrors spec/tools/list_user_changes_tool_spec.rb.

require "rails_helper"

RSpec.describe ListUserChangesTool, type: :model do
  let(:organization) { create(:organization, name: "Test Org") }
  let(:team)         { create(:team, name: "Test Team", organization: organization) }
  let(:user) do
    create(:user, email: "testuser@example.com", confirmation_token: "tok_u1").tap do |u|
      UserPartyRole.create!(user: u, party: team, role: "member")
    end
  end
  let(:other_user) do
    create(:user, email: "other@example.com", confirmation_token: "tok_u2").tap do |u|
      UserPartyRole.create!(user: u, party: team, role: "member")
    end
  end
  let(:project) { create(:project, name: "Test Project", team: team) }
  let(:task)    { create(:task, name: "Test Task", project: project) }

  # The server context hash carries the authenticated user.
  let(:tool) { described_class.new({ user: user }) }

  before { PaperTrail.enabled = true }
  after  { PaperTrail.enabled = false }

  def change_task(record, by:, name:)
    PaperTrail.request.whodunnit = by.id.to_s
    record.update!(name: name)
  end

  describe "#execute" do
    it "includes the current user's own changes" do
      change_task(task, by: user, name: "Renamed by me")
      expect(tool.execute).to include("Task")
    end

    it "excludes changes made by other users (no team_id)" do
      change_task(task, by: other_user, name: "Renamed by other")
      expect(tool.execute).to include("No changes found")
    end

    it "includes team members' changes when scoped to the team" do
      change_task(task, by: other_user, name: "Team change")
      expect(tool.execute(team_id: team.id)).to include("Task")
    end

    it "excludes changes from other teams" do
      other_team    = create(:team, organization: create(:organization, name: "Other Org"))
      other_project = create(:project, team: other_team)
      other_task    = create(:task, name: "Other Task", project: other_project)
      change_task(other_task, by: user, name: "Should not appear")

      expect(tool.execute(team_id: team.id)).not_to include("Other Task")
    end

    it "excludes versions for soft-deleted records" do
      change_task(task, by: user, name: "Before delete")
      task.soft_delete
      filtered = tool.send(:filter_by_team, PaperTrail::Version.all, team)
      expect(filtered.exists?(item_type: "Task", item_id: task.id)).to be false
    end
  end
end
