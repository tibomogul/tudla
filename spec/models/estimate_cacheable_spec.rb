require 'rails_helper'

RSpec.describe EstimateCacheable, type: :model do
  let(:project) { create(:project) }
  let(:scope_record) { create(:scope, project: project) }

  describe "creating a task" do
    it "updates scope cached estimates when task has a scope" do
      create(:task, scope: scope_record, project: project, unassisted_estimate: 10, ai_assisted_estimate: 5, actual_manhours: 3)

      scope_record.reload
      expect(scope_record.cached_unassisted_estimate).to eq(10)
      expect(scope_record.cached_ai_assisted_estimate).to eq(5)
      expect(scope_record.cached_actual_manhours).to eq(3)
    end

    it "updates project cached estimates" do
      create(:task, project: project, unassisted_estimate: 8, ai_assisted_estimate: 4, actual_manhours: 2)

      project.reload
      expect(project.cached_unassisted_estimate).to eq(8)
      expect(project.cached_ai_assisted_estimate).to eq(4)
      expect(project.cached_actual_manhours).to eq(2)
    end

    it "updates both scope and project when task has a scope" do
      create(:task, scope: scope_record, project: project, unassisted_estimate: 10, ai_assisted_estimate: 5, actual_manhours: 3)

      scope_record.reload
      project.reload
      expect(scope_record.cached_unassisted_estimate).to eq(10)
      expect(project.cached_unassisted_estimate).to eq(10)
    end
  end

  describe "updating estimate fields" do
    let!(:task) { create(:task, scope: scope_record, project: project, unassisted_estimate: 10, ai_assisted_estimate: 5, actual_manhours: 3) }

    it "recalculates parent caches when estimates change" do
      task.update!(unassisted_estimate: 20)

      scope_record.reload
      project.reload
      expect(scope_record.cached_unassisted_estimate).to eq(20)
      expect(project.cached_unassisted_estimate).to eq(20)
    end
  end

  describe "moving task between scopes" do
    let(:other_scope) { create(:scope, project: project) }
    let!(:task) { create(:task, scope: scope_record, project: project, unassisted_estimate: 10, ai_assisted_estimate: 5, actual_manhours: 3) }

    it "updates both old and new scope" do
      task.update!(scope: other_scope)

      scope_record.reload
      other_scope.reload
      expect(scope_record.cached_unassisted_estimate).to eq(0)
      expect(other_scope.cached_unassisted_estimate).to eq(10)
    end

    it "keeps project totals unchanged" do
      task.update!(scope: other_scope)

      project.reload
      expect(project.cached_unassisted_estimate).to eq(10)
    end
  end

  describe "moving task between projects" do
    let(:other_project) { create(:project) }
    let!(:task) { create(:task, project: project, unassisted_estimate: 10, ai_assisted_estimate: 5, actual_manhours: 3) }

    it "updates both old and new project" do
      task.update!(project: other_project)

      project.reload
      other_project.reload
      expect(project.cached_unassisted_estimate).to eq(0)
      expect(other_project.cached_unassisted_estimate).to eq(10)
    end
  end

  describe "soft deleting a task" do
    let!(:task) { create(:task, scope: scope_record, project: project, unassisted_estimate: 10, ai_assisted_estimate: 5, actual_manhours: 3) }

    it "decrements parent cached estimates" do
      task.destroy

      scope_record.reload
      project.reload
      expect(scope_record.cached_unassisted_estimate).to eq(0)
      expect(scope_record.cached_ai_assisted_estimate).to eq(0)
      expect(scope_record.cached_actual_manhours).to eq(0)
      expect(project.cached_unassisted_estimate).to eq(0)
    end
  end

  describe "restoring a soft-deleted task" do
    let!(:task) { create(:task, scope: scope_record, project: project, unassisted_estimate: 10, ai_assisted_estimate: 5, actual_manhours: 3) }

    it "increments parent cached estimates" do
      task.destroy

      scope_record.reload
      project.reload
      expect(scope_record.cached_unassisted_estimate).to eq(0)
      expect(project.cached_unassisted_estimate).to eq(0)

      task.restore

      scope_record.reload
      project.reload
      expect(scope_record.cached_unassisted_estimate).to eq(10)
      expect(project.cached_unassisted_estimate).to eq(10)
    end
  end

  describe "multiple tasks" do
    it "sums estimates across all active tasks" do
      create(:task, scope: scope_record, project: project, unassisted_estimate: 10, ai_assisted_estimate: 5, actual_manhours: 3)
      create(:task, scope: scope_record, project: project, unassisted_estimate: 20, ai_assisted_estimate: 15, actual_manhours: 8)

      scope_record.reload
      project.reload
      expect(scope_record.cached_unassisted_estimate).to eq(30)
      expect(scope_record.cached_ai_assisted_estimate).to eq(20)
      expect(scope_record.cached_actual_manhours).to eq(11)
      expect(project.cached_unassisted_estimate).to eq(30)
    end

    it "includes both scoped and unscoped tasks in project totals" do
      create(:task, scope: scope_record, project: project, unassisted_estimate: 10)
      create(:task, project: project, unassisted_estimate: 20)

      project.reload
      expect(project.cached_unassisted_estimate).to eq(30)
    end
  end

  describe "tasks with nil estimates" do
    it "treats nil estimates as 0" do
      create(:task, scope: scope_record, project: project, unassisted_estimate: nil, ai_assisted_estimate: nil, actual_manhours: nil)

      scope_record.reload
      expect(scope_record.cached_unassisted_estimate).to eq(0)
      expect(scope_record.cached_ai_assisted_estimate).to eq(0)
      expect(scope_record.cached_actual_manhours).to eq(0)
    end
  end
end
