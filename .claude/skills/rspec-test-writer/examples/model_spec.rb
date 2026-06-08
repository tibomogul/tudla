# Example: model spec covering associations, the .active soft-delete scope, and
# the EstimateCacheable rollup. Adapt to Task, Scope, Project, etc.
#
# WHY this shape: mirrors spec/models/estimate_cacheable_spec.rb plus the
# soft-delete conventions in references/conventions.md.

require "rails_helper"

RSpec.describe Task, type: :model do
  let(:organization) { create(:organization) }
  let(:team)         { create(:team, organization: organization) }
  let(:project)      { create(:project, team: team) }
  let(:scope)        { create(:scope, project: project) }
  let(:user)         { create(:user) }

  describe "associations" do
    # NOTE: shoulda-matchers is NOT in the Gemfile, so the one-line
    # `it { is_expected.to belong_to(:project) }` form is unavailable and will
    # raise NoMethodError. Assert associations behaviourally instead:
    it "belongs to a project (optional)" do
      expect(create(:task, project: project).project).to eq(project)
      expect(create(:task).project).to be_nil
    end

    it "belongs to a scope (optional)" do
      expect(create(:task, project: project, scope: scope).scope).to eq(scope)
    end

    it "belongs to a responsible_user via the User class (optional)" do
      task = create(:task, project: project, responsible_user: user)
      expect(task.responsible_user).to eq(user)
    end
  end

  describe "#organization" do
    it "walks project -> team -> organization" do
      task = create(:task, project: project)
      expect(task.organization).to eq(organization)
    end

    it "is nil when the task has no project" do
      expect(create(:task).organization).to be_nil
    end
  end

  describe "soft delete" do
    let!(:task) { create(:task, project: project) }

    it "excludes soft-deleted tasks from .active" do
      task.soft_delete
      expect(Task.active).not_to include(task)
      expect(task.deleted_at).to be_present
    end

    it "restores a soft-deleted task" do
      task.soft_delete
      task.restore
      expect(Task.active).to include(task)
      expect(task.deleted_at).to be_nil
    end
  end

  describe "estimate rollup (EstimateCacheable)" do
    it "updates scope and project cached estimates on create" do
      create(:task, scope: scope, project: project,
                    unassisted_estimate: 10, ai_assisted_estimate: 5, actual_manhours: 3)

      scope.reload
      project.reload
      expect(scope.cached_unassisted_estimate).to eq(10)
      expect(project.cached_unassisted_estimate).to eq(10)
    end

    it "decrements parent caches when a task is destroyed" do
      # WHY: use #destroy (which EstimateCacheable overrides to soft-delete AND
      # recalc). Bare #soft_delete is an update_column that skips callbacks, so
      # it flips deleted_at but does NOT touch the cached_* columns.
      task = create(:task, scope: scope, project: project, unassisted_estimate: 10)
      task.destroy

      scope.reload
      project.reload
      expect(scope.cached_unassisted_estimate).to eq(0)
      expect(project.cached_unassisted_estimate).to eq(0)
    end

    it "treats nil estimates as 0" do
      create(:task, scope: scope, project: project, unassisted_estimate: nil)
      scope.reload
      expect(scope.cached_unassisted_estimate).to eq(0)
    end
  end
end
