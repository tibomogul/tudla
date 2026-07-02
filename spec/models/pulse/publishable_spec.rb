require "rails_helper"

RSpec.describe Pulse::Publishable, type: :model do
  let(:organization) { create(:organization) }
  let(:team) { create(:team, organization: organization) }
  let(:actor) { create(:user) }

  after { Pulse::Current.reset }

  describe "subscribable auto-creation" do
    it "creates a subscribable container for projects, scopes and tasks" do
      project = create(:project, team: team)
      scope = create(:scope, project: project)
      task = create(:task, project: project, scope: scope)

      expect(project.subscribable).to be_present
      expect(scope.subscribable).to be_present
      expect(task.subscribable).to be_present
    end
  end

  describe "created events" do
    it "publishes project.created attributed to the current user and auto-subscribes them" do
      Pulse::Current.user = actor

      project = create(:project, team: team)

      event = project.subscribable.events.find_by(action: "project.created")
      expect(event).to have_attributes(user: actor, actor_type: "user")
      expect(event.metadata).to include("subject_name" => project.name, "actor_name" => actor.display_name)
      expect(project.subscribed?(actor)).to be true
    end

    it "publishes with the system actor when no user context is set" do
      project = create(:project, team: team)

      event = project.subscribable.events.find_by(action: "project.created")
      expect(event).to have_attributes(user: nil, actor_type: "system")
      expect(event.metadata["actor_name"]).to eq("System")
    end

    it "attributes agent activity to the token user with actor_type agent" do
      Pulse::Current.user = actor
      Pulse::Current.actor_type = "agent"
      Pulse::Current.actor_label = "ci-token"

      project = create(:project, team: team)

      event = project.subscribable.events.find_by(action: "project.created")
      expect(event).to have_attributes(user: actor, actor_type: "agent", actor_label: "ci-token")
    end
  end

  describe "updated events" do
    let(:project) { create(:project, team: team) }

    it "publishes project.updated for a meaningful change" do
      expect {
        project.update!(name: "Renamed")
      }.to change { project.subscribable.events.where(action: "project.updated").count }.by(1)
    end

    it "skips changes to ignored columns" do
      expect {
        project.update!(risk_state: "yellow", lifecycle_state: "done")
      }.not_to change { project.subscribable.events.where(action: "project.updated").count }
    end
  end

  describe "soft delete and restore" do
    it "publishes task.deleted and task.restored despite update_column skipping callbacks" do
      task = create(:task, project: create(:project, team: team))

      expect { task.soft_delete }
        .to change { task.subscribable.events.where(action: "task.deleted").count }.by(1)
      expect { task.restore }
        .to change { task.subscribable.events.where(action: "task.restored").count }.by(1)
    end

    it "does not let a publish failure break soft_delete or restore" do
      task = create(:task, project: create(:project, team: team))
      allow(Pulse::Publisher).to receive(:publish).and_raise(StandardError, "boom")

      expect { task.soft_delete }.not_to raise_error
      expect(task.reload).to be_deleted
      expect { task.restore }.not_to raise_error
      expect(task.reload).not_to be_deleted
    end
  end

  describe "task.assigned" do
    it "publishes an assignment event and auto-subscribes the assignee" do
      task = create(:task, project: create(:project, team: team))
      assignee = create(:user)

      expect {
        task.update!(responsible_user: assignee)
      }.to change { task.subscribable.events.where(action: "task.assigned").count }.by(1)

      event = task.subscribable.events.where(action: "task.assigned").last
      expect(event.metadata).to include(
        "responsible_user_id" => assignee.id,
        "responsible_user_name" => assignee.display_name
      )
      expect(task.subscribed?(assignee)).to be true
    end

    it "does not publish task.updated for a pure assignment change" do
      task = create(:task, project: create(:project, team: team))

      expect {
        task.update!(responsible_user: create(:user))
      }.not_to change { task.subscribable.events.where(action: "task.updated").count }
    end

    it "publishes task.assigned and auto-subscribes the assignee when the task is created with one" do
      assignee = create(:user)

      task = create(:task, project: create(:project, team: team), responsible_user: assignee)

      event = task.subscribable.events.find_by(action: "task.assigned")
      expect(event).to be_present
      expect(event.metadata).to include("responsible_user_id" => assignee.id)
      expect(task.subscribed?(assignee)).to be true
    end

    it "saves cleanly when the assignee is already subscribed (creator assigning themselves)" do
      Pulse::Current.user = actor

      task = create(:task, project: create(:project, team: team), responsible_user: actor)

      expect(task).to be_persisted
      expect(task.subscribed?(actor)).to be true
      expect(task.subscribable.subscriptions.where(user: actor).count).to eq(1)
    end
  end

  describe "task.unassigned" do
    it "publishes an unassignment event naming the previous assignee" do
      assignee = create(:user)
      task = create(:task, project: create(:project, team: team), responsible_user: assignee)

      expect {
        task.update!(responsible_user: nil)
      }.to change { task.subscribable.events.where(action: "task.unassigned").count }.by(1)

      event = task.subscribable.events.where(action: "task.unassigned").last
      expect(event.metadata).to include(
        "previous_user_id" => assignee.id,
        "previous_user_name" => assignee.display_name
      )
    end

    it "does not publish task.updated for a pure unassignment" do
      task = create(:task, project: create(:project, team: team), responsible_user: create(:user))

      expect {
        task.update!(responsible_user: nil)
      }.not_to change { task.subscribable.events.where(action: "task.updated").count }
    end
  end

  describe "task.transitioned" do
    it "publishes with from/to states and the transition's acting user" do
      task = create(:task, project: create(:project, team: team),
                           responsible_user: actor, unassisted_estimate: 8, ai_assisted_estimate: 4)

      task.state_machine.transition_to!(:in_progress, user_id: actor.id)

      event = task.subscribable.events.where(action: "task.transitioned").last
      expect(event).to have_attributes(user: actor)
      expect(event.metadata).to include("from_state" => "new", "to_state" => "in_progress")
    end

    it "does not let a publish failure raise out of an already-committed transition" do
      task = create(:task, project: create(:project, team: team),
                           responsible_user: actor, unassisted_estimate: 8, ai_assisted_estimate: 4)
      allow(Pulse::Publisher).to receive(:publish).and_raise(StandardError, "boom")

      expect {
        task.state_machine.transition_to!(:in_progress, user_id: actor.id)
      }.not_to raise_error
      expect(task.reload.state).to eq("in_progress")
    end
  end

  describe "project transitions" do
    let(:project) { create(:project, team: team) }

    it "publishes project.transitioned with from/to states and the acting user" do
      project.lifecycle_state_machine.transition_to!(:done, user_id: actor.id)

      event = project.subscribable.events.find_by(action: "project.transitioned")
      expect(event).to have_attributes(user: actor)
      expect(event.metadata).to include("from_state" => "active", "to_state" => "done")
    end

    it "publishes project.risk_changed with from/to states" do
      project.risk_state_machine.transition_to!(:red, user_id: actor.id)

      event = project.subscribable.events.find_by(action: "project.risk_changed")
      expect(event).to have_attributes(user: actor)
      expect(event.metadata).to include("from_state" => "green", "to_state" => "red")
    end

    it "does not let a risk-change publish failure raise out of the committed transition" do
      project # create before stubbing so project.created still publishes normally
      allow(Pulse::Publisher).to receive(:publish).and_raise(StandardError, "boom")

      expect {
        project.risk_state_machine.transition_to!(:red, user_id: actor.id)
      }.not_to raise_error
      expect(project.reload.risk_state).to eq("red")
    end
  end

  describe "note.created" do
    it "publishes against the note's parent subscribable" do
      project = create(:project, team: team)
      notable = Notable.create!(notable: project)

      expect {
        Note.create!(notable: notable, user: actor, content: "A note")
      }.to change { project.subscribable.events.where(action: "note.created").count }.by(1)
    end
  end
end
