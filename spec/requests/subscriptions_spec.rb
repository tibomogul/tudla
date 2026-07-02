require "rails_helper"

RSpec.describe "Subscriptions", type: :request do
  let(:organization) { create(:organization) }
  let(:team) { create(:team, organization: organization) }
  let(:project) { create(:project, team: team) }
  let(:subscribable) { project.subscribable }
  let(:user) { create(:user) }

  before { sign_in(user) }

  describe "POST /subscribables/:id/subscribe" do
    context "when the user can see the underlying project" do
      before { UserPartyRole.create!(user: user, party: organization, role: "member") }

      it "creates a subscription" do
        expect {
          post create_subscription_path(subscribable)
        }.to change(Pulse::Subscription, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(Pulse::Subscription.last).to have_attributes(user_id: user.id, subscribable_id: subscribable.id)
      end

      it "does not create a duplicate subscription" do
        Pulse::Subscription.create!(user: user, subscribable: subscribable)

        expect {
          post create_subscription_path(subscribable)
        }.not_to change(Pulse::Subscription, :count)

        expect(response).to have_http_status(:ok)
      end
    end

    context "when the user has no access to the underlying project" do
      it "denies the request and creates nothing" do
        expect {
          post create_subscription_path(subscribable)
        }.not_to change(Pulse::Subscription, :count)

        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe "DELETE /subscriptions/:id" do
    before { UserPartyRole.create!(user: user, party: organization, role: "member") }

    it "destroys the user's own subscription" do
      subscription = Pulse::Subscription.create!(user: user, subscribable: subscribable)

      expect {
        delete destroy_subscription_path(subscription)
      }.to change(Pulse::Subscription, :count).by(-1)

      expect(response).to have_http_status(:ok)
    end

    it "refuses to destroy another user's subscription" do
      other_subscription = Pulse::Subscription.create!(user: create(:user), subscribable: subscribable)

      expect {
        delete destroy_subscription_path(other_subscription)
      }.not_to change(Pulse::Subscription, :count)

      expect(response).to have_http_status(:redirect)
    end
  end
end
