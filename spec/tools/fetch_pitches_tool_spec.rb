# frozen_string_literal: true

require "rails_helper"

RSpec.describe FetchPitchesTool, type: :model do
  let(:organization) { create(:organization, name: "Test Org") }
  let(:user) do
    create(:user, email: "testuser@example.com", username: "testuser", confirmation_token: "token_fp1").tap do |u|
      UserPartyRole.create!(user: u, party: organization, role: "member")
    end
  end
  let(:other_user) do
    create(:user, email: "otheruser@example.com", username: "otheruser", confirmation_token: "token_fp2").tap do |u|
      UserPartyRole.create!(user: u, party: organization, role: "member")
    end
  end

  let(:tool) { described_class.new({ user: user }) }

  describe "#execute" do
    it "returns pitches within date range by created_at" do
      in_range = create(:pitch, user: user, organization: organization, status: "ready_for_betting", created_at: 2.days.ago)
      out_of_range = create(:pitch, user: user, organization: organization, status: "ready_for_betting", created_at: 10.days.ago)

      result = tool.execute(start_time: 3.days.ago.iso8601, end_time: 1.day.ago.iso8601)

      expect(result).to include(in_range.id.to_s)
      expect(result).not_to include("ID: #{out_of_range.id}")
    end

    it "filters by organization_id" do
      other_org = create(:organization, name: "Other Org")
      UserPartyRole.create!(user: user, party: other_org, role: "member")

      pitch1 = create(:pitch, user: user, organization: organization, status: "ready_for_betting", created_at: 1.day.ago)
      pitch2 = create(:pitch, user: user, organization: other_org, status: "ready_for_betting", created_at: 1.day.ago)

      result = tool.execute(start_time: 2.days.ago.iso8601, end_time: Time.current.iso8601, organization_id: organization.id)

      expect(result).to include(pitch1.id.to_s)
      expect(result).not_to include("ID: #{pitch2.id}")
    end

    it "filters by user_id" do
      user_pitch = create(:pitch, user: user, organization: organization, status: "ready_for_betting", created_at: 1.day.ago)
      other_pitch = create(:pitch, user: other_user, organization: organization, status: "ready_for_betting", created_at: 1.day.ago)

      result = tool.execute(start_time: 2.days.ago.iso8601, end_time: Time.current.iso8601, user_id: user.id)

      expect(result).to include(user_pitch.id.to_s)
      expect(result).not_to include("ID: #{other_pitch.id}")
    end

    it "filters by status" do
      ready = create(:pitch, user: user, organization: organization, status: "ready_for_betting", created_at: 1.day.ago)
      draft = create(:pitch, user: user, organization: organization, status: "draft", created_at: 1.day.ago)

      result = tool.execute(start_time: 2.days.ago.iso8601, end_time: Time.current.iso8601, status: "ready_for_betting")

      expect(result).to include(ready.id.to_s)
      expect(result).not_to include("ID: #{draft.id}")
    end

    it "validates start_time before end_time" do
      expect {
        tool.execute(start_time: 1.day.ago.iso8601, end_time: 3.days.ago.iso8601)
      }.to raise_error(RuntimeError, /start_time must be before end_time/)
    end

    it "excludes soft-deleted pitches" do
      pitch = create(:pitch, user: user, organization: organization, status: "ready_for_betting", created_at: 1.day.ago)
      pitch.soft_delete

      result = tool.execute(start_time: 2.days.ago.iso8601, end_time: Time.current.iso8601)

      expect(result).to include("No pitches found.")
    end

    it "respects policy scope" do
      other_org = create(:organization, name: "Other Org")
      inaccessible_user = create(:user, email: "inaccessible@example.com", confirmation_token: "token_fp3")
      create(:pitch, user: inaccessible_user, organization: other_org, status: "ready_for_betting", created_at: 1.day.ago)

      result = tool.execute(start_time: 2.days.ago.iso8601, end_time: Time.current.iso8601)

      expect(result).to include("No pitches found.")
    end

    it "respects limit" do
      3.times do |i|
        create(:pitch, user: user, organization: organization, status: "ready_for_betting", created_at: (i + 1).hours.ago)
      end

      result = tool.execute(start_time: 2.days.ago.iso8601, end_time: Time.current.iso8601, limit: 2)

      expect(result).to include("2 pitch(es)")
    end
  end
end
