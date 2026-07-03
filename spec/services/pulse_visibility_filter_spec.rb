require "rails_helper"

# PulseVisibilityFilter replaces the per-recipient Pundit check in fan-out
# with one batched role query, so it must agree with the policies' #show?
# for every subject type and role placement — this spec is the drift guard.
RSpec.describe PulseVisibilityFilter do
  let(:organization) { create(:organization) }
  let(:team) { create(:team, organization: organization) }
  let(:project) { create(:project, team: team) }
  let(:scope) { create(:scope, project: project) }
  let(:task) { create(:task, project: project, scope: scope) }

  it "agrees with Pundit #show? for every subject type and role placement" do
    owner = create(:user)
    task.update!(responsible_user: owner)

    users = {
      "no role" => create(:user),
      "organization member" => with_role(organization, "member"),
      "organization admin" => with_role(organization, "admin"),
      "team member" => with_role(team, "member"),
      "project member" => with_role(project, "member"),
      "task owner without any role" => owner
    }

    [ project, scope, task ].each do |subject|
      users.each do |label, user|
        expected = Pundit.policy!(user, subject).show?
        actual = described_class.new.call(subject, [ user ]).include?(user)

        expect(actual).to eq(expected),
          "PulseVisibilityFilter disagrees with #{subject.class}Policy#show? for #{label} " \
          "(policy: #{expected}, filter: #{actual})"
      end
    end
  end

  it "filters the whole recipient set with visibility intact" do
    member = with_role(organization, "member")
    outsider = create(:user)

    expect(described_class.new.call(project, [ member, outsider ])).to contain_exactly(member)
  end

  it "handles subjects in team-less projects" do
    teamless_project = create(:project, team: nil)
    member = create(:user)
    UserPartyRole.create!(user: member, party: teamless_project, role: "member")
    outsider = create(:user)

    expect(described_class.new.call(teamless_project, [ member, outsider ])).to contain_exactly(member)
  end

  def with_role(party, role)
    create(:user).tap { |user| UserPartyRole.create!(user: user, party: party, role: role) }
  end
end
