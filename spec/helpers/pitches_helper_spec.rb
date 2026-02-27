require "rails_helper"

RSpec.describe PitchesHelper, type: :helper do
  describe "#pitch_badge_color" do
    it "returns badge-neutral for draft status" do
      expect(helper.pitch_badge_color("draft")).to eq("badge-neutral")
    end

    it "returns badge-info for ready_for_betting status" do
      expect(helper.pitch_badge_color("ready_for_betting")).to eq("badge-info")
    end

    it "returns badge-success for bet status" do
      expect(helper.pitch_badge_color("bet")).to eq("badge-success")
    end

    it "returns badge-error for rejected status" do
      expect(helper.pitch_badge_color("rejected")).to eq("badge-error")
    end

    it "returns badge-neutral for unknown status" do
      expect(helper.pitch_badge_color("unknown")).to eq("badge-neutral")
    end

    it "handles symbol input" do
      expect(helper.pitch_badge_color(:draft)).to eq("badge-neutral")
    end

    it "handles nil input" do
      expect(helper.pitch_badge_color(nil)).to eq("badge-neutral")
    end
  end

  describe "#pitch_button_color" do
    it "returns btn-neutral for draft status" do
      expect(helper.pitch_button_color("draft")).to eq("btn-neutral")
    end

    it "returns btn-info for ready_for_betting status" do
      expect(helper.pitch_button_color("ready_for_betting")).to eq("btn-info")
    end

    it "returns btn-success for bet status" do
      expect(helper.pitch_button_color("bet")).to eq("btn-success")
    end

    it "returns btn-error for rejected status" do
      expect(helper.pitch_button_color("rejected")).to eq("btn-error")
    end

    it "returns btn-neutral for unknown status" do
      expect(helper.pitch_button_color("unknown")).to eq("btn-neutral")
    end

    it "handles symbol input" do
      expect(helper.pitch_button_color(:bet)).to eq("btn-success")
    end

    it "handles nil input" do
      expect(helper.pitch_button_color(nil)).to eq("btn-neutral")
    end
  end
end
