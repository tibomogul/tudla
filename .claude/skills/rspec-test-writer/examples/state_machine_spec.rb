# Example: Statesman state machine spec. Covers initial state, allowed and
# forbidden transitions, guards (both branches), after_transition side effects,
# and transactional atomicity.
#
# WHY this shape: mirrors spec/state_machines/project_lifecycle_state_machine_spec.rb
# and the patterns in references/statesman-and-papertrail.md.

require "rails_helper"

RSpec.describe TaskStateMachine, type: :model do
  let(:organization) { create(:organization) }
  let(:team)         { create(:team, organization: organization) }
  let(:project)      { create(:project, team: team) }
  let(:user)         { create(:user) }

  describe "initial state" do
    it "starts in new" do
      expect(create(:task, project: project).current_state).to eq("new")
    end
  end

  describe "guard on :in_progress" do
    context "when responsible_user and both estimates are present" do
      let(:task) do
        create(:task, project: project, responsible_user: user,
                      unassisted_estimate: 5, ai_assisted_estimate: 3)
      end

      it "allows new -> in_progress" do
        task.state_machine.transition_to!(:in_progress, user_id: user.id)
        expect(task.current_state).to eq("in_progress")
      end

      it "persists the user_id in transition metadata" do
        task.state_machine.transition_to!(:in_progress, user_id: user.id)
        last = task.task_transitions.order(:sort_key).last
        expect(last.metadata["user_id"]).to eq(user.id)
      end
    end

    context "when an estimate is missing" do
      let(:task) do
        create(:task, project: project, responsible_user: user,
                      unassisted_estimate: nil, ai_assisted_estimate: 3)
      end

      it "is blocked by the guard" do
        expect(task.state_machine.can_transition_to?(:in_progress)).to be false
        expect { task.state_machine.transition_to!(:in_progress) }
          .to raise_error(Statesman::GuardFailedError)
      end
    end
  end

  describe "forbidden transitions" do
    let(:task) { create(:task, project: project) }

    it "raises on new -> done (not an allowed edge)" do
      expect { task.state_machine.transition_to!(:done) }
        .to raise_error(Statesman::TransitionFailedError)
    end
  end

  # The lifecycle machine is the canonical example of after_transition side
  # effects + atomicity. Reproduced here as a second illustration.
  describe ProjectLifecycleStateMachine do
    let!(:scope) { create(:scope, project: project) }
    let!(:task)  { create(:task, project: project, scope: scope) }

    it "propagates lifecycle state to children on transition to done" do
      project.lifecycle_state_machine.transition_to!(:done)
      expect(scope.reload.project_lifecycle_state).to eq("done")
      expect(task.reload.project_lifecycle_state).to eq("done")
      expect(task.reload).to be_read_only
    end

    it "rolls the transition back atomically when propagation fails" do
      allow(project).to receive(:propagate_lifecycle_to_children!)
        .and_raise(ActiveRecord::StatementInvalid, "boom")

      expect { project.lifecycle_state_machine.transition_to!(:archived) }
        .to raise_error(ActiveRecord::StatementInvalid)

      expect(project.reload.lifecycle_state).to eq("active")
      expect(task.reload.project_lifecycle_state).to eq("active")
    end
  end
end
