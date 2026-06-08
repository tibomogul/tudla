# Devise + Pundit Testing

## Devise scope: `:user` (the default)

Tudla authenticates the standard Devise `User` (scope `:user`), with optional Google/Microsoft OAuth. The test helpers are wired in `spec/rails_helper.rb` by spec type:

- `type: :request` → `Devise::Test::IntegrationHelpers` → `sign_in(user)` works directly before issuing requests.
- `type: :controller` / `type: :view` → `Devise::Test::ControllerHelpers`.

```ruby
RSpec.describe "/tasks", type: :request do
  let(:user) { create(:user) }
  before { sign_in(user) }

  it "renders index" do
    get tasks_url
    expect(response).to be_successful
  end
end
```

Always build users through the `:user` factory so Devise confirmation is satisfied (it sets `confirmed_at`/`confirmation_token`). An unconfirmed user cannot sign in.

## Pundit: test the policy directly

The cheapest, highest-signal authorization tests need no controller. A Pundit policy is `FooPolicy.new(user, record)`; each action method returns a boolean:

```ruby
expect(PitchPolicy.new(admin, pitch).update?).to be true
expect(PitchPolicy.new(non_member, pitch).show?).to be false
```

The Scope inner class resolves the relation a user is allowed to see:

```ruby
resolved = PitchPolicy::Scope.new(user, Pitch).resolve
expect(resolved).to include(visible_record)
expect(resolved).not_to include(other_org_record)
expect(resolved).not_to include(soft_deleted_record)   # scopes must respect .active
```

### Setting up actors with UserPartyRole

Authorization flows through `UserPartyRole` (see `references/conventions.md`). A typical policy spec sets up several actors against one organization:

```ruby
let(:organization) { create(:organization) }
let(:creator)    { create(:user) }
let(:member)     { create(:user) }
let(:admin)      { create(:user) }
let(:non_member) { create(:user) }

before do
  UserPartyRole.create!(user: creator, party: organization, role: "member")
  UserPartyRole.create!(user: member,  party: organization, role: "member")
  UserPartyRole.create!(user: admin,   party: organization, role: "admin")
end
```

Then assert the boundary of the rule under test — for an admin-only action, prove admin allowed **and** plain member denied **and** non-member denied.

### Hierarchy edges worth covering

Because access resolves downward only (org-role → teams/projects; team-role → projects; project-role grants nothing upward), include the edge cases the real policy specs do:

```ruby
it "allows a user who only holds a team role in the org" do
  team = create(:team, organization: organization)
  UserPartyRole.create!(user: team_member, party: team, role: "member")
  expect(described_class.new(team_member, draft_pitch).show?).to be true
end

it "prevents a user who only holds a project role" do
  project = create(:project, team: create(:team, organization: organization))
  UserPartyRole.create!(user: project_member, party: project, role: "member")
  expect(described_class.new(project_member, draft_pitch).show?).to be false
end
```

### State-dependent permissions

Many Tudla policies gate on the record's Statesman state (e.g. a draft pitch is editable by its creator/co-authors, but a `bet` pitch is fully locked even for admins). Build the record into the right state via the machine, then assert the policy:

```ruby
let(:bet_pitch) do
  p = create(:pitch, user: creator, organization: organization)
  p.state_machine.transition_to!(:ready_for_betting)
  p.state_machine.transition_to!(:bet)
  p
end

it "prevents even an admin from updating a bet pitch" do
  expect(described_class.new(admin, bet_pitch).update?).to be false
end
```

### Lost-membership edge

When a user keeps a relationship to a record (creator/co-author) but loses org membership, the policy should deny mutation. To test it, strip the role without firing the prune callback and bust the cache:

```ruby
UserPartyRole.where(user: co_author, party: organization).delete_all
co_author.bust_organizations_cache
expect(described_class.new(co_author, draft_pitch).update?).to be false
```

## Authorization at the request layer

Use request specs to verify the controller actually calls `authorize` / `policy_scope` and renders/redirects correctly — not to re-test every rule (that belongs in the policy spec). A denied action in Tudla typically redirects with a flash rather than returning 403; assert against the real behaviour of the controller under test (check `ApplicationController`'s `Pundit::NotAuthorizedError` rescue before asserting a status code).

The canonical, comprehensive reference is `spec/policies/pitch_policy_spec.rb` — read it before writing a new policy spec. Worked example: `examples/policy_spec.rb`.
