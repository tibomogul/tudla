require "rails_helper"

# ProjectsHelper maps a project's risk state to DaisyUI badge/button classes.
# These are pure presentation helpers, so we assert the exact class string for
# every known state plus the fallback for an unknown one. The helpers call
# `state.to_s`, so they accept either a String (as the views pass it) or a
# Symbol — both are exercised.
RSpec.describe ProjectsHelper, type: :helper do
  describe "#risk_badge_color" do
    it "maps each known risk state to its DaisyUI badge class" do
      expect(helper.risk_badge_color("green")).to eq("badge-success")
      expect(helper.risk_badge_color("yellow")).to eq("badge-warning")
      expect(helper.risk_badge_color("red")).to eq("badge-error")
    end

    it "coerces symbol states via to_s" do
      expect(helper.risk_badge_color(:green)).to eq("badge-success")
      expect(helper.risk_badge_color(:red)).to eq("badge-error")
    end

    it "falls back to badge-ghost for an unknown or nil state" do
      expect(helper.risk_badge_color("purple")).to eq("badge-ghost")
      expect(helper.risk_badge_color(nil)).to eq("badge-ghost")
    end
  end

  describe "#risk_button_color" do
    it "maps each known risk state to its DaisyUI button class" do
      expect(helper.risk_button_color("green")).to eq("btn-success")
      expect(helper.risk_button_color("yellow")).to eq("btn-warning")
      expect(helper.risk_button_color("red")).to eq("btn-error")
    end

    it "coerces symbol states via to_s" do
      expect(helper.risk_button_color(:yellow)).to eq("btn-warning")
      expect(helper.risk_button_color(:green)).to eq("btn-success")
    end

    it "falls back to btn-neutral for an unknown or nil state" do
      expect(helper.risk_button_color("purple")).to eq("btn-neutral")
      expect(helper.risk_button_color(nil)).to eq("btn-neutral")
    end
  end
end
