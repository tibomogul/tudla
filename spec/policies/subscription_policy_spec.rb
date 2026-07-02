require "rails_helper"

RSpec.describe SubscriptionPolicy do
  let(:organization) { create(:organization) }
  let(:team) { create(:team, organization: organization) }
  let(:project) { create(:project, team: team) }
  let(:subscribable) { project.subscribable }
  let(:user) { create(:user) }

  describe "#create?" do
    let(:subscription) { Pulse::Subscription.new(user: user, subscribable: subscribable) }

    it "allows a user who can see the underlying subject" do
      UserPartyRole.create!(user: user, party: organization, role: "member")

      expect(described_class.new(user, subscription).create?).to be true
    end

    it "denies a user without access to the underlying subject" do
      expect(described_class.new(user, subscription).create?).to be false
    end
  end

  describe "#destroy?" do
    it "allows the owner" do
      subscription = Pulse::Subscription.create!(user: user, subscribable: subscribable)

      expect(described_class.new(user, subscription).destroy?).to be true
    end

    it "denies another user" do
      subscription = Pulse::Subscription.create!(user: create(:user), subscribable: subscribable)

      expect(described_class.new(user, subscription).destroy?).to be false
    end
  end

  describe "Scope" do
    it "returns only the user's subscriptions" do
      mine = Pulse::Subscription.create!(user: user, subscribable: subscribable)
      Pulse::Subscription.create!(user: create(:user), subscribable: subscribable)

      resolved = described_class::Scope.new(user, Pulse::Subscription.all).resolve

      expect(resolved).to contain_exactly(mine)
    end
  end
end
