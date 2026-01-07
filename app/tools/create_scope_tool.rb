# frozen_string_literal: true

class CreateScopeTool < ApplicationTool
  description "Create a new scope within a project"

  annotations(
    title: "Create Scope",
    read_only_hint: false
  )

  arguments do
    required(:name).filled(:string).description("Name of the scope")
    required(:project_id).filled(:integer).description("Project ID for the scope")
    optional(:description).maybe(:string).description("Description of the scope")
    optional(:nice_to_have).filled(:bool).description("Whether the scope is nice to have (not required)")
    optional(:hill_chart_progress).filled(:integer).description("Hill chart progress (0-100)")
  end

  def call(name:, project_id:, description: nil, nice_to_have: false, hill_chart_progress: 0)
    project = Project.find_by(id: project_id)
    raise "Project not found with ID: #{project_id}" unless project

    scope = Scope.new(
      name: name,
      description: description,
      project_id: project_id,
      nice_to_have: nice_to_have,
      hill_chart_progress: hill_chart_progress
    )
    
    # Authorize using Pundit - user must have create permission
    authorize(scope, :create?)

    if scope.save
      "Scope created successfully!\n\n#{GetScopeTool.new.call(scope_id: scope.id)}"
    else
      raise "Failed to create scope: #{scope.errors.full_messages.join(', ')}"
    end
  end
end
