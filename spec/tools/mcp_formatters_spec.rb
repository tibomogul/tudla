# frozen_string_literal: true

require "rails_helper"

RSpec.describe McpFormatters, type: :model do
  let(:organization) { create(:organization, name: "Test Org") }
  let(:team) { create(:team, name: "Test Team", organization: organization) }
  let(:project) { create(:project, name: "Test Project", team: team) }
  let(:scope_record) { create(:scope, name: "Test Scope", project: project) }

  # Create a simple test class that includes the concern
  let(:formatter) do
    Class.new do
      include McpFormatters
    end.new
  end

  describe "#format_scope_summary" do
    context "with active and soft-deleted tasks" do
      before do
        create(:task, name: "Active Task 1", scope: scope_record, project: project)
        create(:task, name: "Active Task 2", scope: scope_record, project: project)
        create(:task, name: "Deleted Task", scope: scope_record, project: project, deleted_at: 1.day.ago)
      end

      it "excludes soft-deleted tasks from task count" do
        result = formatter.format_scope_summary(scope_record)

        # Should show "Tasks: 2" (only active tasks), not "Tasks: 3"
        expect(result).to include("Tasks: 2")
        expect(result).not_to include("Tasks: 3")
      end
    end

    context "with only soft-deleted tasks" do
      before do
        create(:task, name: "Deleted Task", scope: scope_record, project: project, deleted_at: 1.day.ago)
      end

      it "shows zero task count" do
        result = formatter.format_scope_summary(scope_record)

        expect(result).to include("Tasks: 0")
      end
    end
  end

  describe "#format_scope_details" do
    context "with active and soft-deleted tasks" do
      before do
        create(:task, name: "Active Task", scope: scope_record, project: project)
        create(:task, name: "Deleted Task", scope: scope_record, project: project, deleted_at: 1.day.ago)
      end

      it "only lists active tasks in details output" do
        result = formatter.format_scope_details(scope_record)

        expect(result).to include("Active Task")
        expect(result).not_to include("Deleted Task")
      end

      it "shows correct task count in details header" do
        result = formatter.format_scope_details(scope_record)

        expect(result).to include("Tasks (1)")
        expect(result).not_to include("Tasks (2)")
      end
    end

    context "with only soft-deleted tasks" do
      before do
        create(:task, name: "Deleted Task", scope: scope_record, project: project, deleted_at: 1.day.ago)
      end

      it "does not show tasks section when all tasks are soft-deleted" do
        result = formatter.format_scope_details(scope_record)

        expect(result).not_to include("Tasks (")
        expect(result).not_to include("Deleted Task")
      end
    end
  end

  describe "#format_project_summary" do
    context "with active and soft-deleted scopes and tasks" do
      before do
        create(:scope, name: "Active Scope", project: project)
        create(:scope, name: "Deleted Scope", project: project, deleted_at: 1.day.ago)
        create(:task, name: "Active Task", project: project)
        create(:task, name: "Deleted Task", project: project, deleted_at: 1.day.ago)
      end

      it "excludes soft-deleted scopes from scope count" do
        result = formatter.format_project_summary(project)

        expect(result).to include("Scopes: 1")
        expect(result).not_to include("Scopes: 2")
      end

      it "excludes soft-deleted tasks from task count" do
        result = formatter.format_project_summary(project)

        expect(result).to include("Tasks: 1")
        expect(result).not_to include("Tasks: 2")
      end
    end
  end

  describe "#format_project_details" do
    context "with active and soft-deleted scopes" do
      before do
        create(:scope, name: "Active Scope", project: project)
        create(:scope, name: "Deleted Scope", project: project, deleted_at: 1.day.ago)
      end

      it "only lists active scopes in details output" do
        result = formatter.format_project_details(project)

        expect(result).to include("Active Scope")
        expect(result).not_to include("Deleted Scope")
      end

      it "shows correct scope count in details header" do
        result = formatter.format_project_details(project)

        expect(result).to include("Scopes (1)")
        expect(result).not_to include("Scopes (2)")
      end
    end

    context "with only soft-deleted scopes" do
      before do
        create(:scope, name: "Deleted Scope", project: project, deleted_at: 1.day.ago)
      end

      it "does not show scopes section when all scopes are soft-deleted" do
        result = formatter.format_project_details(project)

        expect(result).not_to include("Scopes (")
        expect(result).not_to include("Deleted Scope")
      end
    end
  end
end
