# Example: ViewComponent spec. Use type: :component and include the
# ViewComponent/Capybara helpers in the spec (they are not globally configured).
# Stub Pundit policy gating via vc_test_controller.
#
# WHY this shape: mirrors spec/components/note_row_component_spec.rb.

require "rails_helper"

RSpec.describe NoteRowComponent, type: :component do
  include ViewComponent::TestHelpers
  include Capybara::RSpecMatchers

  let(:organization) { create(:organization) }
  let(:team)         { create(:team, organization: organization) }
  let(:project)      { create(:project, team: team) }
  let(:notable)      { Notable.create!(notable: project) }
  let(:owner) do
    create(:user, email: "owner@example.com", preferred_name: "Owen", confirmation_token: "row_owner")
  end
  let(:note) { Note.create!(notable: notable, user: owner, content: "body", title: "Hello") }

  before do
    UserPartyRole.create!(user: owner, party: organization, role: "member")
  end

  # WHY: the component reads policy(note).edit?/destroy? off the controller.
  # Stub it with a verifying instance_double so rendering does not depend on a
  # real signed-in user.
  def build(edit: true, destroy: true)
    policy = instance_double(NotePolicy, edit?: edit, destroy?: destroy)
    allow(vc_test_controller).to receive(:policy).with(note).and_return(policy)
    described_class.new(note: note)
  end

  describe "rendering" do
    it "renders the title and last editor name" do
      render_inline(build)
      expect(page).to have_text("Hello")
      expect(page).to have_text("Owen")
    end

    it "shows the edited badge when updated well after creation" do
      note.update_columns(updated_at: note.created_at + 5.minutes)
      render_inline(build)
      expect(page).to have_css(".badge", text: "edited")
    end
  end

  describe "policy gating" do
    it "renders Edit/Delete when the policy allows" do
      render_inline(build(edit: true, destroy: true))
      expect(page).to have_css("a[href='/notes/#{note.id}/edit']")
    end

    it "hides Edit/Delete when the policy denies" do
      render_inline(build(edit: false, destroy: false))
      expect(page).not_to have_css("a[href='/notes/#{note.id}/edit']")
    end
  end
end
