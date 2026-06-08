# Example: view helper spec. Helper specs (type: :helper) expose a `helper`
# object that includes the helper under test plus ApplicationHelper.
#
# Replace TasksHelper / the method names with the real helper under test.

require "rails_helper"

RSpec.describe TasksHelper, type: :helper do
  # WHY: pure formatting/presentation helpers are the cheapest meaningful
  # coverage — no DB, fast feedback. Assert the actual output, not be_present.

  describe "#task_state_badge_class" do
    it "maps each state to its DaisyUI badge class" do
      expect(helper.task_state_badge_class("new")).to eq("badge-primary")
      expect(helper.task_state_badge_class("in_progress")).to eq("badge-info")
      expect(helper.task_state_badge_class("in_review")).to eq("badge-warning")
      expect(helper.task_state_badge_class("done")).to eq("badge-success")
      expect(helper.task_state_badge_class("blocked")).to eq("badge-error")
    end
  end

  # When a helper formats time, it must go through the organization timezone,
  # not the wall clock. Freeze time so the assertion is deterministic.
  describe "#formatted_due" do
    it "renders the due date in the organization timezone" do
      organization = create(:organization, timezone: "Australia/Brisbane")
      team    = create(:team, organization: organization)
      project = create(:project, team: team)
      task    = create(:task, project: project)

      travel_to(Time.utc(2026, 1, 15, 23, 0)) do
        # 23:00 UTC is 09:00 next day in Brisbane (UTC+10) — assert the org-tz value.
        expect(helper.formatted_due(task, Time.current)).to include("16 Jan")
      end
    end
  end
end
