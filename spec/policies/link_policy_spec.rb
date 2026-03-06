require "rails_helper"

RSpec.describe LinkPolicy, type: :policy do
  let(:organization) { create(:organization) }
  let(:member) { create(:user) }
  let(:non_member) { create(:user) }

  before do
    UserPartyRole.create!(user: member, party: organization, role: "member")
  end

  shared_examples "link access via linkable" do |notable_factory|
    let(:record) { create(notable_factory, organization: organization) }
    let(:linkable) { Linkable.create!(linkable_type: record.class.name, linkable_id: record.id) }
    let(:link) { Link.new(linkable: linkable, user: member, url: "https://example.com") }

    it "allows org member to create" do
      expect(described_class.new(member, link).create?).to be true
    end

    it "prevents non-member from creating" do
      expect(described_class.new(non_member, link).create?).to be false
    end
  end

  describe "with Cycle linkable" do
    include_examples "link access via linkable", :cycle
  end

  describe "with Pitch linkable" do
    include_examples "link access via linkable", :pitch do
      let(:record) { create(:pitch, user: member, organization: organization) }
    end
  end
end
