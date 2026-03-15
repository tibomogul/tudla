# frozen_string_literal: true

require "rails_helper"

RSpec.describe FetchReportsTool, type: :model do
  let(:organization) { create(:organization, name: "Test Org") }
  let(:team) { create(:team, name: "Test Team", organization: organization) }
  let(:user) do
    create(:user, email: "testuser@example.com", username: "testuser", confirmation_token: "token_fr1").tap do |u|
      UserPartyRole.create!(user: u, party: team, role: "member")
    end
  end
  let(:other_user) do
    create(:user, email: "otheruser@example.com", username: "otheruser", confirmation_token: "token_fr2").tap do |u|
      UserPartyRole.create!(user: u, party: team, role: "member")
    end
  end
  let(:project) { create(:project, name: "Test Project", team: team) }
  let(:reportable_for_project) { Reportable.create!(reportable: project) }
  let(:reportable_for_team) { Reportable.create!(reportable: team) }

  let(:tool) { described_class.new({ user: user }) }

  describe "#execute" do
    it "returns reports within date range by as_of_at" do
      in_range = create(:report, user: user, reportable: reportable_for_project, as_of_at: 2.days.ago, submitted_at: 2.days.ago)
      out_of_range = create(:report, user: user, reportable: reportable_for_project, as_of_at: 10.days.ago, submitted_at: 10.days.ago)

      result = tool.execute(start_time: 3.days.ago.iso8601, end_time: 1.day.ago.iso8601)

      expect(result).to include(in_range.id.to_s)
      expect(result).not_to include("ID: #{out_of_range.id}")
    end

    it "filters by team_id including team and project reportables" do
      team_report = create(:report, user: user, reportable: reportable_for_team, as_of_at: 1.day.ago, submitted_at: 1.day.ago)
      project_report = create(:report, user: user, reportable: reportable_for_project, as_of_at: 1.day.ago, submitted_at: 1.day.ago)

      result = tool.execute(start_time: 2.days.ago.iso8601, end_time: Time.current.iso8601, team_id: team.id)

      expect(result).to include(team_report.id.to_s)
      expect(result).to include(project_report.id.to_s)
    end

    it "filters by user_id" do
      user_report = create(:report, user: user, reportable: reportable_for_project, as_of_at: 1.day.ago, submitted_at: 1.day.ago)
      other_report = create(:report, user: other_user, reportable: reportable_for_project, as_of_at: 1.day.ago, submitted_at: 1.day.ago)

      result = tool.execute(start_time: 2.days.ago.iso8601, end_time: Time.current.iso8601, user_id: user.id)

      expect(result).to include(user_report.id.to_s)
      expect(result).not_to include("ID: #{other_report.id}")
    end

    it "validates start_time before end_time" do
      expect {
        tool.execute(start_time: 1.day.ago.iso8601, end_time: 3.days.ago.iso8601)
      }.to raise_error(RuntimeError, /start_time must be before end_time/)
    end

    it "excludes drafts by default (submitted_only: true)" do
      submitted = create(:report, user: user, reportable: reportable_for_project, as_of_at: 1.day.ago, submitted_at: 1.day.ago)
      draft = create(:report, user: user, reportable: reportable_for_project, as_of_at: 1.day.ago, submitted_at: nil)

      result = tool.execute(start_time: 2.days.ago.iso8601, end_time: Time.current.iso8601)

      expect(result).to include(submitted.id.to_s)
      expect(result).not_to include("ID: #{draft.id}")
    end

    it "excludes soft-deleted reports" do
      report = create(:report, user: user, reportable: reportable_for_project, as_of_at: 1.day.ago, submitted_at: 1.day.ago)
      report.soft_delete

      result = tool.execute(start_time: 2.days.ago.iso8601, end_time: Time.current.iso8601)

      expect(result).to include("No reports found.")
    end

    it "respects policy scope" do
      other_org = create(:organization, name: "Other Org")
      other_team = create(:team, name: "Inaccessible Team", organization: other_org)
      other_project = create(:project, name: "Inaccessible Project", team: other_team)
      inaccessible_user = create(:user, email: "inaccessible@example.com", confirmation_token: "token_fr3")
      other_reportable = Reportable.create!(reportable: other_project)

      create(:report, user: inaccessible_user, reportable: other_reportable, as_of_at: 1.day.ago, submitted_at: 1.day.ago)

      result = tool.execute(start_time: 2.days.ago.iso8601, end_time: Time.current.iso8601)

      expect(result).to include("No reports found.")
    end

    it "respects limit" do
      3.times do |i|
        create(:report, user: user, reportable: reportable_for_project, as_of_at: (i + 1).hours.ago, submitted_at: (i + 1).hours.ago)
      end

      result = tool.execute(start_time: 2.days.ago.iso8601, end_time: Time.current.iso8601, limit: 2)

      expect(result).to include("2 report(s)")
    end
  end
end
