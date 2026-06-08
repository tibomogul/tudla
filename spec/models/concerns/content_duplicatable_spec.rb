require "rails_helper"

RSpec.describe ContentDuplicatable do
  # Exercised through the live use case: copying a Pitch's content onto a Project.
  let(:author) { create(:user) }
  let(:editor) { create(:user) }
  let(:source) { create(:pitch, user: author) }
  let(:target) { create(:project) }

  def attach_file(attachment)
    attachment.file.attach(
      io: StringIO.new("file bytes"),
      filename: "doc.png",
      content_type: "image/png"
    )
  end

  describe "#copy_content_to" do
    let!(:source_note) do
      notable = Notable.create!(notable: source)
      notable.notes.create!(title: "Spec", content: "Body", user: author, last_editor_id: editor.id)
    end

    let!(:source_link) do
      linkable = Linkable.create!(linkable: source)
      linkable.links.create!(url: "https://example.com", description: "Docs", user: author)
    end

    let!(:source_attachment) do
      attachable = Attachable.create!(attachable: source)
      attachment = attachable.attachments.build(description: "Diagram", user: author)
      attach_file(attachment)
      attachment.save!
      attachment
    end

    it "returns the target" do
      expect(source.copy_content_to(target)).to eq(target)
    end

    it "copies notes by value with preserved authorship" do
      source.copy_content_to(target)

      copy = target.notes.active.sole
      expect(copy).not_to eq(source_note)
      expect(copy).to have_attributes(
        title: "Spec",
        content: "Body",
        user_id: author.id,
        last_editor_id: editor.id
      )
    end

    it "copies links by value with preserved authorship" do
      source.copy_content_to(target)

      copy = target.links.active.sole
      expect(copy).not_to eq(source_link)
      expect(copy).to have_attributes(url: "https://example.com", description: "Docs", user_id: author.id)
    end

    it "copies attachments as new records sharing the source blob" do
      source.copy_content_to(target)

      copy = target.attachments.active.sole
      expect(copy).not_to eq(source_attachment)
      expect(copy.user_id).to eq(author.id)
      expect(copy.description).to eq("Diagram")
      expect(copy.file).to be_attached
      expect(copy.file.blob).to eq(source_attachment.file.blob)
    end

    it "leaves the source content untouched" do
      source.copy_content_to(target)

      expect(source.notes.active).to contain_exactly(source_note)
      expect(source.links.active).to contain_exactly(source_link)
      expect(source.attachments.active).to contain_exactly(source_attachment)
    end

    it "skips soft-deleted children" do
      Note.create!(notable: source_note.notable, user: author, title: "Gone", content: "x").soft_delete
      Link.create!(linkable: source_link.linkable, user: author, url: "https://gone.example.com").soft_delete

      source.copy_content_to(target)

      expect(target.notes.active.pluck(:title)).to contain_exactly("Spec")
      expect(target.links.active.pluck(:url)).to contain_exactly("https://example.com")
    end

    it "adds to a target that already has its own content" do
      existing_notable = Notable.create!(notable: target)
      existing = existing_notable.notes.create!(title: "Kept", content: "Own", user: author)

      source.copy_content_to(target)

      expect(target.notes.active.pluck(:title)).to contain_exactly("Kept", "Spec")
      expect(existing.reload.title).to eq("Kept")
    end
  end

  describe "guarding the target" do
    it "raises ArgumentError when the target lacks the content associations" do
      expect { source.copy_content_to(Object.new) }.to raise_error(ArgumentError)
    end
  end

  context "when the source has no content" do
    it "creates nothing and leaves no wrappers on the target" do
      source.copy_content_to(target)

      expect(target.notes.active).to be_empty
      expect(target.links.active).to be_empty
      expect(target.attachments.active).to be_empty
      expect(Notable.find_by(notable: target)).to be_nil
    end
  end
end
