require "rails_helper"

RSpec.describe "User#member_organizations", type: :model do
  let(:user) { create(:user) }
  let(:org_a) { create(:organization, name: "Alpha Org") }
  let(:org_b) { create(:organization, name: "Beta Org") }

  after { user.bust_organizations_cache }

  it "returns organizations where the user has a direct role" do
    UserPartyRole.create!(user: user, party: org_a, role: "admin")

    expect(user.member_organizations).to eq([ org_a ])
  end

  it "returns organizations derived from team roles" do
    team = create(:team, organization: org_a)
    UserPartyRole.create!(user: user, party: team, role: "member")

    expect(user.member_organizations).to eq([ org_a ])
  end

  it "excludes organizations reachable only through a project role" do
    team = create(:team, organization: org_a)
    project = create(:project, team: team)
    UserPartyRole.create!(user: user, party: project, role: "member")

    expect(user.member_organizations).to eq([])
  end

  it "deduplicates organizations across role types" do
    team = create(:team, organization: org_a)
    UserPartyRole.create!(user: user, party: org_a, role: "admin")
    UserPartyRole.create!(user: user, party: team, role: "member")

    expect(user.member_organizations).to eq([ org_a ])
  end

  it "returns multiple organizations ordered by name" do
    UserPartyRole.create!(user: user, party: org_a, role: "admin")
    UserPartyRole.create!(user: user, party: org_b, role: "member")

    expect(user.member_organizations).to eq([ org_a, org_b ])
  end

  it "excludes soft-deleted organizations" do
    UserPartyRole.create!(user: user, party: org_a, role: "admin")

    org_a.update!(deleted_at: Time.current)
    user.bust_organizations_cache

    expect(user.member_organizations).to eq([])
  end

  it "returns empty array when the user has no roles" do
    expect(user.member_organizations).to eq([])
  end

  it "busts the cache when a UserPartyRole changes" do
    expect(user.member_organizations).to eq([])

    UserPartyRole.create!(user: user, party: org_a, role: "member")

    expect(user.member_organizations).to eq([ org_a ])
  end
end
