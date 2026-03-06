require "rails_helper"

RSpec.describe NotePolicy, type: :policy do
  let(:organization) { create(:organization) }
  let(:member) { create(:user) }
  let(:non_member) { create(:user) }

  before do
    UserPartyRole.create!(user: member, party: organization, role: "member")
  end

  shared_examples "note access via notable" do |notable_factory|
    let(:record) { create(notable_factory, organization: organization) }
    let(:notable) { Notable.create!(notable_type: record.class.name, notable_id: record.id) }
    let(:note) { Note.new(notable: notable, user: member, content: "test") }

    it "allows org member to create" do
      expect(described_class.new(member, note).create?).to be true
    end

    it "prevents non-member from creating" do
      expect(described_class.new(non_member, note).create?).to be false
    end
  end

  describe "with Cycle notable" do
    include_examples "note access via notable", :cycle
  end

  describe "with Pitch notable" do
    include_examples "note access via notable", :pitch do
      let(:record) { create(:pitch, user: member, organization: organization) }
    end
  end
end
