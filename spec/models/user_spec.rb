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
end
