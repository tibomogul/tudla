require "rails_helper"

RSpec.describe Attachable, type: :model do
  describe "delegated_type :attachable" do
    it "can own each of the declared delegated types" do
      owners = {
        "Project"      => create(:project),
        "Scope"        => create(:scope, project: create(:project)),
        "Task"         => create(:task),
        "Team"         => create(:team),
        "Organization" => create(:organization)
      }

      owners.each do |type_name, owner|
        attachable = Attachable.create!(attachable: owner)

        expect(attachable.attachable_type).to eq(type_name)
        expect(attachable.attachable_id).to eq(owner.id)
        expect(attachable.attachable).to eq(owner)
      end
    end

    it "exposes the polymorphic owner record through #attachable" do
      task = create(:task)
      attachable = create(:attachable, attachable: task)

      expect(attachable.reload.attachable).to eq(task)
      expect(attachable.attachable).to be_a(Task)
    end

    it "names the delegated-type accessors after the declared types" do
      # delegated_type generates predicate + accessor methods per declared type.
      task = create(:task)
      attachable = create(:attachable, attachable: task)

      expect(attachable).to respond_to(:task)
      expect(attachable.task).to eq(task)
      expect(attachable).to respond_to(:project, :scope, :team, :organization)
    end
  end

  describe "#attachments" do
    let(:attachable) { create(:attachable) }

    it "returns the attachments belonging to this attachable" do
      mine  = create(:attachment, attachable: attachable)
      other = create(:attachment, attachable: create(:attachable))

      expect(attachable.attachments).to include(mine)
      expect(attachable.attachments).not_to include(other)
    end

    it "exposes both active and soft-deleted attachments (no implicit .active)" do
      live    = create(:attachment, attachable: attachable)
      deleted = create(:attachment, attachable: attachable)
      deleted.soft_delete

      expect(attachable.attachments).to include(live)
      expect(attachable.attachments).to include(deleted)
      expect(attachable.attachments.active).to contain_exactly(live)
    end
  end

  describe "host-model through-association wiring" do
    it "round-trips attachments from a host model through its attachable" do
      project = create(:project)

      expect(project.attachable).to be_nil

      attachable = Attachable.create!(attachable: project)
      attachment = create(:attachment, attachable: attachable)

      expect(project.reload.attachable).to eq(attachable)
      expect(project.attachments).to include(attachment)
    end

    it "wires the through-association for every host type" do
      hosts = [
        create(:project),
        create(:scope, project: create(:project)),
        create(:task),
        create(:team),
        create(:organization)
      ]

      hosts.each do |host|
        attachable = Attachable.create!(attachable: host)
        attachment = create(:attachment, attachable: attachable)

        expect(host.reload.attachments).to include(attachment)
      end
    end
  end

  describe "role in ContentDuplicatable#copy_content_to (attachments)" do
    let(:author) { create(:user) }
    let(:source) { create(:project) }
    let(:target) { create(:project) }

    def add_attachment(host, user:, filename:, content_type: "image/png", description: nil)
      attachable = Attachable.find_or_create_by!(attachable_type: host.class.name, attachable_id: host.id)
      attachment = attachable.attachments.build(description: description, user: user)
      attachment.file.attach(
        io: StringIO.new("blob-#{filename}"),
        filename: filename,
        content_type: content_type
      )
      attachment.save!
      attachment
    end

    it "lazily creates an Attachable on the target and copies active attachments onto it" do
      add_attachment(source, user: author, filename: "a.png", description: "first")

      expect { source.copy_content_to(target) }
        .to change { Attachable.where(attachable_type: "Project", attachable_id: target.id).count }.from(0).to(1)

      copied = target.reload.attachments
      expect(copied.size).to eq(1)
      expect(copied.first.description).to eq("first")
    end

    it "preserves the original author rather than the copier" do
      copier = create(:user)
      add_attachment(source, user: author, filename: "a.png")

      source.copy_content_to(target)

      expect(target.reload.attachments.first.user).to eq(author)
      expect(target.attachments.first.user).not_to eq(copier)
    end

    it "shares the immutable source blob instead of re-uploading" do
      original = add_attachment(source, user: author, filename: "a.png")

      source.copy_content_to(target)
      copy = target.reload.attachments.first

      # Independent Attachment rows, but the same underlying blob (deduped storage).
      expect(copy).not_to eq(original)
      expect(copy.file.blob).to eq(original.file.blob)
      expect(copy.filename).to eq("a.png")
    end

    it "skips soft-deleted source attachments" do
      add_attachment(source, user: author, filename: "live.png")
      deleted = add_attachment(source, user: author, filename: "gone.png")
      deleted.soft_delete

      source.copy_content_to(target)

      filenames = target.reload.attachments.map(&:filename)
      expect(filenames).to contain_exactly("live.png")
    end

    it "does not create an Attachable on the target when the source has no active attachments" do
      deleted = add_attachment(source, user: author, filename: "gone.png")
      deleted.soft_delete

      source.copy_content_to(target)

      expect(Attachable.where(attachable_type: "Project", attachable_id: target.id)).to be_empty
      expect(target.reload.attachments).to be_empty
    end

    it "copies attachments in creation order" do
      first  = add_attachment(source, user: author, filename: "1.png", description: "one")
      second = add_attachment(source, user: author, filename: "2.png", description: "two")
      # Force a deterministic created_at ordering independent of insertion timing.
      first.update_column(:created_at, 2.hours.ago)
      second.update_column(:created_at, 1.hour.ago)

      source.copy_content_to(target)

      expect(target.reload.attachments.order(:created_at).map(&:description)).to eq(%w[one two])
    end
  end
end
