require "rails_helper"

RSpec.describe Note, type: :model do
  let(:organization) { create(:organization) }
  let(:team) { create(:team, organization: organization) }
  let(:project) { create(:project, team: team) }
  let(:notable) { Notable.create!(notable: project) }
  let(:creator) { create(:user, email: "creator@example.com", confirmation_token: "n_creator") }
  let(:editor)  { create(:user, email: "editor@example.com",  confirmation_token: "n_editor") }
  let(:other)   { create(:user, email: "other@example.com",   confirmation_token: "n_other") }

  describe "#assign_last_editor" do
    it "sets last_editor to the creator on initial save" do
      note = Note.create!(notable: notable, user: creator, content: "v1")
      expect(note.last_editor).to eq(creator)
    end

    it "uses PaperTrail whodunnit when content changes" do
      note = Note.create!(notable: notable, user: creator, content: "v1")
      PaperTrail.request(whodunnit: editor.id) do
        note.update!(content: "v2")
      end
      expect(note.reload.last_editor).to eq(editor)
    end

    it "prefers `current_editor` over PaperTrail whodunnit" do
      note = Note.create!(notable: notable, user: creator, content: "v1")
      note.current_editor = other
      PaperTrail.request(whodunnit: editor.id) do
        note.update!(content: "v2")
      end
      expect(note.reload.last_editor).to eq(other)
    end

    it "does NOT bump last_editor when only non-content/title columns change" do
      note = Note.create!(notable: notable, user: creator, content: "v1")
      original_editor = note.last_editor
      PaperTrail.request(whodunnit: editor.id) do
        note.touch # only updated_at changes
      end
      expect(note.reload.last_editor).to eq(original_editor)
    end

    it "ignores non-numeric whodunnit values" do
      note = Note.create!(notable: notable, user: creator, content: "v1")
      PaperTrail.request(whodunnit: "system") do
        note.update!(content: "v2")
      end
      # last_editor stays as creator since "system" doesn't cast to a valid id
      expect(note.reload.last_editor).to eq(creator)
    end
  end

  describe "#parent_record" do
    it "returns the underlying delegated record" do
      note = Note.create!(notable: notable, user: creator, content: "x")
      expect(note.parent_record).to eq(project)
    end
  end
end
