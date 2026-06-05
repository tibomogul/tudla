require "rails_helper"

RSpec.describe User, type: :model do
  describe "#display_name" do
    let(:user) { build(:user, email: "owen.h@example.com") }

    it "prefers preferred_name when present" do
      user.preferred_name = "Owen"
      user.username = "owen.h"
      expect(user.display_name).to eq("Owen")
    end

    it "falls back to username when preferred_name is blank" do
      user.preferred_name = ""
      user.username = "owen.h"
      expect(user.display_name).to eq("owen.h")
    end

    it "falls back to email when preferred_name and username are both blank" do
      user.preferred_name = nil
      user.username = nil
      expect(user.display_name).to eq("owen.h@example.com")
    end

    it "treats blank strings as missing, not as a value" do
      user.preferred_name = "   "
      user.username = ""
      expect(user.display_name).to eq("owen.h@example.com")
    end
  end

  describe "#soft_delete" do
    let(:organization) { create(:organization) }
    let(:creator) { create(:user) }
    let(:co_author) { create(:user) }
    let(:pitch) { create(:pitch, user: creator, organization: organization) }

    it "destroys the user's co-author join rows so they lose authorship" do
      PitchCoAuthor.create!(pitch: pitch, user: co_author)

      expect { co_author.destroy }
        .to change { PitchCoAuthor.where(user: co_author).count }.from(1).to(0)
      expect(co_author.reload).to be_deleted
    end
  end
end
