require "rails_helper"

RSpec.describe PolymorphicParentReadOnly, type: :policy do
  # Host class exposes the private helpers for direct testing.
  let(:host_class) do
    Class.new do
      include PolymorphicParentReadOnly
      public :parent_read_only?, :resolve_polymorphic_parent
    end
  end

  let(:host) { host_class.new }
  let(:organization) { create(:organization) }
  let(:team) { create(:team, organization: organization) }
  let(:project) { create(:project, team: team) }
  let(:scope) { create(:scope, project: project) }
  let(:task) { create(:task, project: project, scope: scope) }
  let(:user) { create(:user) }

  def note_on(parent)
    notable = Notable.create!(notable: parent)
    Note.new(notable: notable, user: user, content: "x")
  end

  context "when parent is an active project" do
    it "returns false" do
      expect(host.parent_read_only?(note_on(project), :notable)).to be false
    end
  end

  context "when parent project is archived" do
    before { project.lifecycle_state_machine.transition_to!(:archived) }

    it "returns true for direct project parent" do
      expect(host.parent_read_only?(note_on(project.reload), :notable)).to be true
    end

    it "returns true for scope parent (via denormalized column)" do
      expect(host.parent_read_only?(note_on(Scope.find(scope.id)), :notable)).to be true
    end

    it "returns true for task parent (via denormalized column)" do
      expect(host.parent_read_only?(note_on(Task.find(task.id)), :notable)).to be true
    end
  end

  context "when parent is a non-lifecycle type" do
    it "returns false for Organization" do
      expect(host.parent_read_only?(note_on(organization), :notable)).to be false
    end

    it "returns false for Team" do
      expect(host.parent_read_only?(note_on(team), :notable)).to be false
    end
  end

  context "resolve_polymorphic_parent" do
    it "returns nil when owner has no proxy" do
      dummy = double(notable: nil)
      expect(host.resolve_polymorphic_parent(dummy, :notable)).to be_nil
    end
  end
end
