require "rails_helper"

RSpec.describe NoteRowComponent, type: :component do
  include ViewComponent::TestHelpers
  include Capybara::RSpecMatchers

  let(:organization) { create(:organization) }
  let(:team) { create(:team, organization: organization) }
  let(:project) { create(:project, team: team) }
  let(:notable) { Notable.create!(notable: project) }
  let(:owner) do
    create(:user,
      email: "owner@example.com",
      preferred_name: "Owen",
      confirmation_token: "row_owner")
  end
  let(:other) do
    create(:user,
      email: "other@example.com",
      preferred_name: "Olive",
      confirmation_token: "row_other")
  end
  let(:note) { Note.create!(notable: notable, user: owner, content: "body", title: "Hello") }

  before do
    UserPartyRole.create!(user: owner, party: organization, role: "member")
  end

  def build(note_arg = note, edit: true, destroy: true)
    policy = instance_double(NotePolicy, edit?: edit, destroy?: destroy)
    allow(vc_test_controller).to receive(:policy).with(note_arg).and_return(policy)
    described_class.new(note: note_arg)
  end

  describe "rendering" do
    it "renders the title and last editor name" do
      render_inline(build)
      expect(page).to have_text("Hello")
      expect(page).to have_text("Owen")
    end

    it "falls back to 'Untitled note' when title is blank" do
      note.update!(title: "")
      render_inline(build)
      expect(page).to have_text("Untitled note")
    end

    it "shows the edited badge when updated_at is well after created_at" do
      note.update_columns(updated_at: note.created_at + 5.minutes)
      render_inline(build)
      expect(page).to have_css(".badge", text: "edited")
    end

    it "does not show the edited badge for fresh notes" do
      render_inline(build)
      expect(page).not_to have_css(".badge", text: "edited")
    end

    it "renders a Show button wired to the note-modal stimulus controller" do
      render_inline(build)
      btn = page.find('[data-controller="note-modal"]')
      expect(btn[:"data-note-modal-url-value"]).to eq("/notes/#{note.id}")
      expect(btn[:"data-action"]).to include("note-modal#open")
    end
  end

  describe "policy gating" do
    it "renders Edit and Delete when policy allows" do
      render_inline(build(edit: true, destroy: true))
      expect(page).to have_css("a[href='/notes/#{note.id}/edit']")
      expect(page).to have_css("form[action='/notes/#{note.id}']")
    end

    it "hides Edit and Delete when policy denies" do
      render_inline(build(edit: false, destroy: false))
      expect(page).not_to have_css("a[href='/notes/#{note.id}/edit']")
      expect(page).not_to have_css("form[action='/notes/#{note.id}']")
      expect(page).to have_css('[data-controller="note-modal"]')
    end
  end

  describe "#last_editor" do
    it "returns the creator when there are no edit versions" do
      component = described_class.new(note: note)
      expect(component.last_editor).to eq(owner)
    end

    it "returns the user who last edited via PaperTrail whodunnit" do
      PaperTrail.request(whodunnit: other.id) do
        note.update!(content: "edited body")
      end
      component = described_class.new(note: note)
      expect(component.last_editor).to eq(other)
    end
  end
end
