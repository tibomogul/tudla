require "rails_helper"

RSpec.describe Pulse::FanoutJob, type: :job do
  let(:organization) { create(:organization) }
  let(:team) { create(:team, organization: organization) }
  let(:project) { create(:project, team: team) }
  let(:actor) { create(:user) }
  let(:subscriber) { create(:user) }

  before do
    UserPartyRole.create!(user: actor, party: organization, role: "member")
    UserPartyRole.create!(user: subscriber, party: organization, role: "member")
  end

  def publish_event(subject: project, action: "project.updated", user: actor)
    Pulse::Publisher.publish(subject: subject, action: action, user: user)
  end

  it "creates a notification for each subscriber" do
    project.subscribe(subscriber)
    event = publish_event

    expect {
      described_class.perform_now(event.id)
    }.to change { subscriber.notifications.count }.by(1)

    expect(subscriber.notifications.last.event).to eq(event)
  end

  it "never notifies the actor about their own action" do
    project.subscribe(actor)
    project.subscribe(subscriber)
    event = publish_event

    described_class.perform_now(event.id)

    expect(actor.notifications).to be_empty
    expect(subscriber.notifications.count).to eq(1)
  end

  it "is idempotent across retries" do
    project.subscribe(subscriber)
    event = publish_event

    described_class.perform_now(event.id)
    described_class.perform_now(event.id)

    expect(subscriber.notifications.count).to eq(1)
  end

  it "skips soft-deleted recipients" do
    project.subscribe(subscriber)
    subscriber.soft_delete
    event = publish_event

    expect { described_class.perform_now(event.id) }.not_to change(Pulse::Notification, :count)
  end

  it "skips recipients who can no longer see the subject" do
    outsider = create(:user) # subscribed but holds no role in the org
    project.subscribe(outsider)
    event = publish_event

    described_class.perform_now(event.id)

    expect(outsider.notifications).to be_empty
  end

  it "does nothing when the event has been deleted" do
    event = publish_event
    event.destroy!

    expect { described_class.perform_now(event.id) }.not_to change(Pulse::Notification, :count)
  end

  describe "reviewer rule (host resolver)" do
    it "notifies project admins when a task transitions to in_review, even unsubscribed" do
      admin = create(:user)
      UserPartyRole.create!(user: admin, party: project, role: "admin")
      task = create(:task, project: project, responsible_user: actor,
                           unassisted_estimate: 8, ai_assisted_estimate: 4)
      task.state_machine.transition_to!(:in_progress, user_id: actor.id)
      task.state_machine.transition_to!(:in_review, user_id: actor.id)

      event = task.subscribable.events.where(action: "task.transitioned")
        .find { |e| e.metadata["to_state"] == "in_review" }
      described_class.perform_now(event.id)

      expect(admin.notifications.map(&:event)).to include(event)
    end
  end
end
