require "rails_helper"

RSpec.describe CyclesHelper, type: :helper do
  describe "#cycle_badge_color" do
    it "returns badge-info for shaping state" do
      expect(helper.cycle_badge_color("shaping")).to eq("badge-info")
    end

    it "returns badge-warning for betting state" do
      expect(helper.cycle_badge_color("betting")).to eq("badge-warning")
    end

    it "returns badge-success for active state" do
      expect(helper.cycle_badge_color("active")).to eq("badge-success")
    end

    it "returns badge-ghost for completed state" do
      expect(helper.cycle_badge_color("completed")).to eq("badge-ghost")
    end

    it "returns badge-ghost for unknown state" do
      expect(helper.cycle_badge_color("unknown")).to eq("badge-ghost")
    end

    it "handles symbol input" do
      expect(helper.cycle_badge_color(:shaping)).to eq("badge-info")
    end

    it "handles nil input" do
      expect(helper.cycle_badge_color(nil)).to eq("badge-ghost")
    end
  end

  describe "#cycle_button_color" do
    it "returns btn-neutral for shaping state" do
      expect(helper.cycle_button_color("shaping")).to eq("btn-neutral")
    end

    it "returns btn-warning for betting state" do
      expect(helper.cycle_button_color("betting")).to eq("btn-warning")
    end

    it "returns btn-success for active state" do
      expect(helper.cycle_button_color("active")).to eq("btn-success")
    end

    it "returns btn-neutral for completed state" do
      expect(helper.cycle_button_color("completed")).to eq("btn-neutral")
    end

    it "returns btn-neutral for unknown state" do
      expect(helper.cycle_button_color("unknown")).to eq("btn-neutral")
    end

    it "handles symbol input" do
      expect(helper.cycle_button_color(:active)).to eq("btn-success")
    end

    it "handles nil input" do
      expect(helper.cycle_button_color(nil)).to eq("btn-neutral")
    end
  end
end
