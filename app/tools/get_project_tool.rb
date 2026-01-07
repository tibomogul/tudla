# frozen_string_literal: true

class GetProjectTool < ApplicationTool
  description "Get detailed information about a specific project"

  annotations(
    title: "Get Project Details",
    read_only_hint: true
  )

  arguments do
    required(:project_id).filled(:integer).description("ID of the project to retrieve")
  end

  def call(project_id:)
    projects = Project.where(id: project_id)
    projects = scope_projects_by_user(projects)
    project = projects.first

    raise "Project not found with ID: #{project_id}" unless project

    format_project_details(project)
  end
end
