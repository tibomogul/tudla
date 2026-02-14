# frozen_string_literal: true

class ListProjectsTool < ApplicationTool
  description "List all projects"

  annotations(
    title: "List Projects",
    read_only_hint: true
  )

  input_schema(
    properties: {
      limit: { type: "integer", description: "Maximum number of projects to return (default: 50)" }
    }
  )

  def execute(limit: 50)
    projects = Project.active.limit(limit).order(created_at: :desc)
    projects = scope_projects_by_user(projects)

    format_projects(projects)
  end
end
