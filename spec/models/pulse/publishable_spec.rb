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
