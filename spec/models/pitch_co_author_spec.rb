require "rails_helper"

RSpec.describe PitchCoAuthor, type: :model do
  let(:organization) { create(:organization) }
  let(:pitch) { create(:pitch, organization: organization) }
  let(:user) { create(:user) }

  describe "associations" do
    it "belongs to a pitch" do
      expect(described_class.new(pitch: pitch, user: user).pitch).to eq(pitch)
    end

    it "belongs to a user" do
      expect(described_class.new(pitch: pitch, user: user).user).to eq(user)
    end
  end

  describe "validations" do
    it "is valid with a pitch and user" do
      expect(described_class.new(pitch: pitch, user: user)).to be_valid
    end

    it "prevents the same user being a co-author twice on one pitch" do
      described_class.create!(pitch: pitch, user: user)
      duplicate = described_class.new(pitch: pitch, user: user)
      expect(duplicate).not_to be_valid
    end

    it "allows the same user to co-author different pitches" do
      other_pitch = create(:pitch, organization: organization)
      described_class.create!(pitch: pitch, user: user)
      expect(described_class.new(pitch: other_pitch, user: user)).to be_valid
    end
  end
end
