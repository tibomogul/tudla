require "rails_helper"

RSpec.describe Pulse::Subscription, type: :model do
  describe "uniqueness" do
    it "rejects a duplicate subscription for the same user and subscribable" do
      subscription = create(:pulse_subscription)

      duplicate = described_class.new(user: subscription.user, subscribable: subscription.subscribable)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to be_present
    end

    it "allows the same user to subscribe to different subscribables" do
      subscription = create(:pulse_subscription)
      other = create(:pulse_subscribable, subscribable: create(:project))

      expect(described_class.new(user: subscription.user, subscribable: other)).to be_valid
    end

    it "is enforced at the database level" do
      subscription = create(:pulse_subscription)

      expect {
        described_class.new(user: subscription.user, subscribable: subscription.subscribable)
          .save!(validate: false)
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
