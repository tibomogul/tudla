require "rails_helper"

# TasksHelper holds two pure presentation helpers that map a task state string
# to a DaisyUI CSS class. These are cheap, meaningful tests — assert the exact
# class returned for every mapped state plus the default fallback branch, which
# is the part most likely to silently break in a refactor.
RSpec.describe TasksHelper, type: :helper do
  describe "#badge_color" do
    it "maps each known state to its DaisyUI badge class" do
      expect(helper.badge_color("new")).to eq("badge-primary")
      expect(helper.badge_color("in_progress")).to eq("badge-info")
      expect(helper.badge_color("in_review")).to eq("badge-warning")
      expect(helper.badge_color("done")).to eq("badge-success")
      expect(helper.badge_color("blocked")).to eq("badge-error")
    end

    it "falls back to badge-ghost for an unknown state" do
      expect(helper.badge_color("nonexistent")).to eq("badge-ghost")
    end

    it "falls back to badge-ghost for nil" do
      expect(helper.badge_color(nil)).to eq("badge-ghost")
    end
  end

  describe "#button_color" do
    it "maps each known state to its DaisyUI button class" do
      expect(helper.button_color("in_progress")).to eq("btn-info")
      expect(helper.button_color("in_review")).to eq("btn-warning")
      expect(helper.button_color("done")).to eq("btn-success")
      expect(helper.button_color("blocked")).to eq("btn-error")
    end

    it "coerces the state to a string before looking it up" do
      # button_color calls state.to_s, so a symbol must resolve the same way.
      expect(helper.button_color(:done)).to eq("btn-success")
    end

    it "falls back to btn-neutral for the unmapped 'new' state" do
      # "new" is intentionally absent from the button mapping.
      expect(helper.button_color("new")).to eq("btn-neutral")
    end

    it "falls back to btn-neutral for an unknown state" do
      expect(helper.button_color("nonexistent")).to eq("btn-neutral")
    end

    it "falls back to btn-neutral for nil" do
      # nil.to_s is "", which is unmapped → default.
      expect(helper.button_color(nil)).to eq("btn-neutral")
    end
  end
end
