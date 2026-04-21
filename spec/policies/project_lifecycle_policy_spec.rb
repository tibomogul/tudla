require "rails_helper"

RSpec.describe "Project lifecycle read-only policy enforcement", type: :policy do
  let(:organization) { create(:organization) }
  let(:team) { create(:team, organization: organization) }
  let(:admin) { create(:user) }
  let(:member) { create(:user) }
  let(:project) { create(:project, team: team) }

  before do
    UserPartyRole.create!(user: admin, party: organization, role: "admin")
    UserPartyRole.create!(user: member, party: team, role: "member")
  end

  describe "ProjectPolicy" do
    context "when project is active" do
      it "admin can update" do
        expect(ProjectPolicy.new(admin, project).update?).to be true
      end

      it "admin can transition to done or archived, not active" do
        policy = ProjectPolicy.new(admin, project)
        expect(policy.can_transition_to?(:done)).to be true
        expect(policy.can_transition_to?(:archived)).to be true
        expect(policy.can_transition_to?(:active)).to be false
      end
    end

    context "when project is done" do
      before { project.lifecycle_state_machine.transition_to!(:done) }

      it "forbids update" do
        expect(ProjectPolicy.new(admin, project).update?).to be false
      end

      it "admin can transition to archived or active, not done" do
        policy = ProjectPolicy.new(admin, project)
        expect(policy.can_transition_to?(:done)).to be false
        expect(policy.can_transition_to?(:archived)).to be true
        expect(policy.can_transition_to?(:active)).to be true
      end
    end

    context "when project is archived" do
      before { project.lifecycle_state_machine.transition_to!(:archived) }

      it "forbids update" do
        expect(ProjectPolicy.new(admin, project).update?).to be false
      end

      it "admin can only transition to active" do
        policy = ProjectPolicy.new(admin, project)
        expect(policy.can_transition_to?(:done)).to be false
        expect(policy.can_transition_to?(:archived)).to be false
        expect(policy.can_transition_to?(:active)).to be true
      end

      it "non-admin member cannot reopen" do
        expect(ProjectPolicy.new(member, project).can_transition_to?(:active)).to be false
      end
    end
  end

  describe "ScopePolicy / TaskPolicy read-only propagation" do
    let!(:scope) { create(:scope, project: project) }
    let!(:task) { create(:task, project: project, scope: scope, responsible_user: member) }

    context "when project active" do
      it "allows scope update" do
        expect(ScopePolicy.new(admin, scope).update?).to be true
      end

      it "allows task update" do
        expect(TaskPolicy.new(member, task).update?).to be true
      end

      it "allows task destroy for owner" do
        expect(TaskPolicy.new(member, task).destroy?).to be true
      end
    end

    context "when project archived" do
      before { project.lifecycle_state_machine.transition_to!(:archived) }

      it "blocks scope update without loading project" do
        reloaded_scope = Scope.find(scope.id)
        expect(ScopePolicy.new(admin, reloaded_scope).update?).to be false
      end

      it "blocks scope create" do
        expect(ScopePolicy.new(admin, Scope.find(scope.id)).create?).to be false
      end

      it "blocks task update" do
        expect(TaskPolicy.new(member, Task.find(task.id)).update?).to be false
      end

      it "blocks task destroy even for owner" do
        expect(TaskPolicy.new(member, Task.find(task.id)).destroy?).to be false
      end
    end
  end

  describe "NotePolicy / LinkPolicy / AttachmentPolicy block on archived parent" do
    let!(:scope) { create(:scope, project: project) }
    let!(:task) { create(:task, project: project, scope: scope) }

    before { project.lifecycle_state_machine.transition_to!(:archived) }

    it "blocks note creation on archived project's task" do
      reloaded_task = Task.find(task.id)
      notable = Notable.create!(notable_type: "Task", notable_id: reloaded_task.id)
      note = Note.new(notable: notable, user: admin, content: "x")
      expect(NotePolicy.new(admin, note).create?).to be false
    end

    it "blocks link creation on archived project's scope" do
      reloaded_scope = Scope.find(scope.id)
      linkable = Linkable.create!(linkable_type: "Scope", linkable_id: reloaded_scope.id)
      link = Link.new(linkable: linkable, user: admin, url: "https://example.com", description: "t")
      expect(LinkPolicy.new(admin, link).create?).to be false
    end

    it "blocks attachment creation on archived project" do
      attachable = Attachable.create!(attachable_type: "Project", attachable_id: project.id)
      attachment = Attachment.new(attachable: attachable, user: admin)
      expect(AttachmentPolicy.new(admin, attachment).create?).to be false
    end
  end
end
