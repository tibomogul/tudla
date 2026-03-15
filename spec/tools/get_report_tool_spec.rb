# frozen_string_literal: true

require "rails_helper"

RSpec.describe GetReportTool, type: :model do
  let(:organization) { create(:organization, name: "Test Org") }
  let(:team) { create(:team, name: "Test Team", organization: organization) }
  let(:user) do
    create(:user, email: "testuser@example.com", username: "testuser", confirmation_token: "token_gr1").tap do |u|
      UserPartyRole.create!(user: u, party: organization, role: "member")
    end
  end
  let(:project) { create(:project, name: "Test Project", team: team) }
  let(:reportable_for_project) { Reportable.create!(reportable: project) }

  let(:tool) { described_class.new({ user: user }) }

  describe "#execute" do
    it "returns report details with content" do
      report = create(:report, user: user, reportable: reportable_for_project, content: "Detailed report content", as_of_at: 1.day.ago, submitted_at: 1.day.ago)

      result = tool.execute(report_id: report.id)

      expect(result).to include(report.id.to_s)
      expect(result).to include("Detailed report content")
      expect(result).to include("Submitted")
    end

    it "raises error when report not found" do
      expect { tool.execute(report_id: -1) }.to raise_error(RuntimeError, /Report not found/)
    end

    it "raises error when report not accessible via policy scope" do
      other_org = create(:organization, name: "Other Org")
      other_team = create(:team, name: "Other Team", organization: other_org)
      other_project = create(:project, name: "Other Project", team: other_team)
      other_user = create(:user, email: "otheruser@example.com", confirmation_token: "token_gr2")
      other_reportable = Reportable.create!(reportable: other_project)

      report = create(:report, user: other_user, reportable: other_reportable, as_of_at: 1.day.ago, submitted_at: 1.day.ago)

      expect { tool.execute(report_id: report.id) }.to raise_error(RuntimeError, /Report not found/)
    end

    it "excludes soft-deleted reports" do
      report = create(:report, user: user, reportable: reportable_for_project, as_of_at: 1.day.ago, submitted_at: 1.day.ago)
      report.soft_delete

      expect { tool.execute(report_id: report.id) }.to raise_error(RuntimeError, /Report not found/)
    end
  end
end
