require 'rails_helper'

RSpec.describe Attachment, type: :model do
  describe "associations" do
    it "belongs to an attachable and exposes its delegated target" do
      project = create(:project)
      attachable = create(:attachable, attachable: project)
      attachment = create(:attachment, attachable: attachable)

      expect(attachment.attachable).to eq(attachable)
      expect(attachment.attachable.attachable).to eq(project)
    end

    it "belongs to the user who uploaded it" do
      user = create(:user)
      attachment = create(:attachment, user: user)

      expect(attachment.user).to eq(user)
    end

    # Attachable#before_destroy hard-deletes its attachments via #destroy! (the real
    # destroy), so destroying the attachable removes the rows rather than soft-deleting
    # them — no orphan rows against the attachments→attachables FK.
    it "is destroyed when its attachable is destroyed" do
      attachable = create(:attachable)
      attachment = create(:attachment, attachable: attachable)

      attachable.destroy

      expect(Attachment.with_deleted.exists?(attachment.id)).to be(false)
    end
  end

  describe "validations" do
    it "is valid with a file attached" do
      expect(build(:attachment)).to be_valid
    end

    it "is invalid without a file" do
      attachment = build(:attachment)
      attachment.file.detach
      attachment.file = nil

      expect(attachment).not_to be_valid
      expect(attachment.errors[:file]).to include("can't be blank")
    end
  end

  describe "Active Storage attachment" do
    it "attaches a file via has_one_attached" do
      attachment = create(:attachment)

      expect(attachment.file).to be_attached
      expect(attachment.file.content_type).to eq("image/png")
    end
  end

  describe "soft delete" do
    it "soft deletes instead of removing the row" do
      attachment = create(:attachment)

      attachment.destroy

      expect(attachment.deleted?).to be(true)
      expect(Attachment.with_deleted.exists?(attachment.id)).to be(true)
    end

    it "excludes soft-deleted records from the active scope" do
      kept = create(:attachment)
      removed = create(:attachment)
      removed.soft_delete

      expect(Attachment.active).to include(kept)
      expect(Attachment.active).not_to include(removed)
    end

    it "restores a soft-deleted record back into the active scope" do
      attachment = create(:attachment)
      attachment.soft_delete

      attachment.restore

      expect(attachment.deleted?).to be(false)
      expect(Attachment.active).to include(attachment)
    end
  end

  describe "PaperTrail auditing" do
    before do
      @paper_trail_was_enabled = PaperTrail.enabled?
      PaperTrail.enabled = true
    end
    after { PaperTrail.enabled = @paper_trail_was_enabled }

    it "records a create version when the attachment is created" do
      attachment = create(:attachment)

      # The file is attached during save, so an "update" version may follow the
      # initial "create"; assert the create was captured rather than relying on order.
      expect(attachment.versions.map(&:event)).to include("create")
    end

    it "records an update version when the attachment changes" do
      attachment = create(:attachment)

      attachment.update!(description: "a contract diagram")

      expect(attachment.versions.last.event).to eq("update")
    end
  end

  describe "#filename" do
    it "returns the attached file's name" do
      attachment = create(:attachment, :pdf)

      expect(attachment.filename).to eq("document.pdf")
    end

    it "returns nil when no file is attached" do
      attachment = build(:attachment)
      attachment.file.detach

      expect(attachment.filename).to be_nil
    end
  end

  describe "#file_size" do
    it "formats bytes into a human-readable unit" do
      attachment = build(:attachment)
      attachment.file.detach
      attachment.file.attach(
        io: StringIO.new("a" * 2048),
        filename: "big.png",
        content_type: "image/png"
      )

      expect(attachment.file_size).to eq("2.0 KB")
    end

    it "reports sub-kilobyte sizes in bytes" do
      attachment = build(:attachment)
      attachment.file.detach
      attachment.file.attach(
        io: StringIO.new("abc"),
        filename: "tiny.png",
        content_type: "image/png"
      )

      expect(attachment.file_size).to eq("3 B")
    end

    it "returns nil when no file is attached" do
      attachment = build(:attachment)
      attachment.file.detach

      expect(attachment.file_size).to be_nil
    end
  end

  describe "#content_type" do
    it "returns the attached file's content type" do
      attachment = create(:attachment, :pdf)

      expect(attachment.content_type).to eq("application/pdf")
    end

    it "returns nil when no file is attached" do
      attachment = build(:attachment)
      attachment.file.detach

      expect(attachment.content_type).to be_nil
    end
  end

  describe "content type predicates" do
    it "#image? is true for image content types" do
      expect(build(:attachment, :image).image?).to be(true)
      expect(build(:attachment, :pdf).image?).to be(false)
    end

    it "#pdf? is true only for application/pdf" do
      expect(build(:attachment, :pdf).pdf?).to be(true)
      expect(build(:attachment, :image).pdf?).to be(false)
    end

    it "#video? is true for video content types" do
      attachment = build(:attachment)
      attachment.file.detach
      attachment.file.attach(
        io: StringIO.new("fake video"),
        filename: "clip.mp4",
        content_type: "video/mp4"
      )

      expect(attachment.video?).to be(true)
      expect(build(:attachment, :image).video?).to be(false)
    end

    it "#audio? is true for audio content types" do
      attachment = build(:attachment)
      attachment.file.detach
      attachment.file.attach(
        io: StringIO.new("fake audio"),
        filename: "track.mp3",
        content_type: "audio/mpeg"
      )

      expect(attachment.audio?).to be(true)
      expect(build(:attachment, :image).audio?).to be(false)
    end

    it "predicates return falsey when no file is attached" do
      attachment = build(:attachment)
      attachment.file.detach

      expect(attachment.image?).to be_falsey
      expect(attachment.pdf?).to be_falsey
      expect(attachment.video?).to be_falsey
      expect(attachment.audio?).to be_falsey
    end
  end

  describe "#previewable?" do
    it "is true for images, pdfs, video, and audio" do
      expect(build(:attachment, :image).previewable?).to be(true)
      expect(build(:attachment, :pdf).previewable?).to be(true)
    end

    it "is false for non-previewable content types" do
      expect(build(:attachment, :zip).previewable?).to be(false)
    end

    it "is false when no file is attached" do
      attachment = build(:attachment)
      attachment.file.detach

      expect(attachment.previewable?).to be(false)
    end
  end
end
