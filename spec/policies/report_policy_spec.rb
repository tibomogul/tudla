# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReportPolicy do
  let(:user) { create(:user) }
  let(:organization) { create(:organization) }
  let(:team) { create(:team, organization: organization) }
  let(:reportable) { create(:reportable, reportable: team) }
  let(:report) { create(:report, user: user, reportable: reportable) }

  before do
    UserPartyRole.create!(user: user, party: team, role: "admin")
  end

  subject { described_class.new(user, report) }

  describe "#ai_assist?" do
    it "allows any logged-in user" do
      expect(subject.ai_assist?).to be true
    end
  end

  describe "#render_markdown?" do
    it "allows any logged-in user" do
      expect(subject.render_markdown?).to be true
    end
  end
end
