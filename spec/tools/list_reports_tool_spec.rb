# frozen_string_literal: true

require "rails_helper"

RSpec.describe ListReportsTool, type: :model do
  let(:organization) { create(:organization, name: "Test Org") }
  let(:team) { create(:team, name: "Test Team", organization: organization) }
  let(:user) do
    create(:user, email: "testuser@example.com", username: "testuser", confirmation_token: "token_lr1").tap do |u|
      UserPartyRole.create!(user: u, party: organization, role: "member")
    end
  end
  let(:other_user) do
    create(:user, email: "otheruser@example.com", username: "otheruser", confirmation_token: "token_lr2")
  end
  let(:project) { create(:project, name: "Test Project", team: team) }
  let(:reportable_for_project) { Reportable.create!(reportable: project) }
  let(:reportable_for_team) { Reportable.create!(reportable: team) }

  let(:tool) { described_class.new({ user: user }) }

  describe "#execute" do
    it "returns reports accessible to current user" do
      report = create(:report, user: user, reportable: reportable_for_project, as_of_at: 1.day.ago, submitted_at: 1.day.ago)

      result = tool.execute

      expect(result).to include("report(s)")
      expect(result).to include(report.id.to_s)
    end

    it "filters by project_id" do
      other_team = create(:team, name: "Other Team", organization: organization)
      other_project = create(:project, name: "Other Project", team: other_team)
      other_reportable = Reportable.create!(reportable: other_project)

      report1 = create(:report, user: user, reportable: reportable_for_project, as_of_at: 1.day.ago, submitted_at: 1.day.ago)
      report2 = create(:report, user: user, reportable: other_reportable, as_of_at: 1.day.ago, submitted_at: 1.day.ago)

      result = tool.execute(project_id: project.id)

      expect(result).to include(report1.id.to_s)
      expect(result).not_to include("ID: #{report2.id}")
    end

    it "filters by team_id including team and project reportables" do
      team_report = create(:report, user: user, reportable: reportable_for_team, as_of_at: 1.day.ago, submitted_at: 1.day.ago)
      project_report = create(:report, user: user, reportable: reportable_for_project, as_of_at: 1.day.ago, submitted_at: 1.day.ago)

      result = tool.execute(team_id: team.id)

      expect(result).to include(team_report.id.to_s)
      expect(result).to include(project_report.id.to_s)
    end

    it "excludes drafts by default (submitted_only: true)" do
      submitted = create(:report, user: user, reportable: reportable_for_project, as_of_at: 1.day.ago, submitted_at: 1.day.ago)
      draft = create(:report, user: user, reportable: reportable_for_project, as_of_at: 1.day.ago, submitted_at: nil)

      result = tool.execute

      expect(result).to include(submitted.id.to_s)
      expect(result).not_to include("ID: #{draft.id}")
    end

    it "includes drafts when submitted_only is false" do
      draft = create(:report, user: user, reportable: reportable_for_project, as_of_at: 1.day.ago, submitted_at: nil)

      result = tool.execute(submitted_only: false)

      expect(result).to include(draft.id.to_s)
    end

    it "excludes soft-deleted reports" do
      report = create(:report, user: user, reportable: reportable_for_project, as_of_at: 1.day.ago, submitted_at: 1.day.ago)
      report.soft_delete

      result = tool.execute

      expect(result).to include("No reports found.")
    end

    it "respects policy scope - user cannot see inaccessible reports" do
      other_org = create(:organization, name: "Other Org")
      other_team_obj = create(:team, name: "Inaccessible Team", organization: other_org)
      other_project = create(:project, name: "Inaccessible Project", team: other_team_obj)
      other_reportable = Reportable.create!(reportable: other_project)

      create(:report, user: other_user, reportable: other_reportable, as_of_at: 1.day.ago, submitted_at: 1.day.ago)

      result = tool.execute

      expect(result).to include("No reports found.")
    end

    it "respects limit" do
      3.times do |i|
        create(:report, user: user, reportable: reportable_for_project, as_of_at: i.days.ago, submitted_at: i.days.ago)
      end

      result = tool.execute(limit: 2)

      expect(result).to include("2 report(s)")
    end
  end
end
