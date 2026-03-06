require "rails_helper"

RSpec.describe AttachmentPolicy, type: :policy do
  let(:organization) { create(:organization) }
  let(:member) { create(:user) }
  let(:non_member) { create(:user) }

  before do
    UserPartyRole.create!(user: member, party: organization, role: "member")
  end

  shared_examples "attachment access via attachable" do |notable_factory|
    let(:record) { create(notable_factory, organization: organization) }
    let(:attachable) { Attachable.create!(attachable_type: record.class.name, attachable_id: record.id) }
    let(:attachment) { Attachment.new(attachable: attachable, user: member) }

    it "allows org member to create" do
      expect(described_class.new(member, attachment).create?).to be true
    end

    it "prevents non-member from creating" do
      expect(described_class.new(non_member, attachment).create?).to be false
    end
  end

  describe "with Cycle attachable" do
    include_examples "attachment access via attachable", :cycle
  end

  describe "with Pitch attachable" do
    include_examples "attachment access via attachable", :pitch do
      let(:record) { create(:pitch, user: member, organization: organization) }
    end
  end
end
