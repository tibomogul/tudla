# frozen_string_literal: true

class CreateScopeTool < ApplicationTool
  description "Create a new scope within a project"

  annotations(
    title: "Create Scope",
    read_only_hint: false
  )

  input_schema(
    properties: {
      name: { type: "string", description: "Name of the scope" },
      project_id: { type: "integer", description: "Project ID for the scope" },
      description: { type: "string", description: "Description of the scope" },
      nice_to_have: { type: "boolean", description: "Whether the scope is nice to have (not required)" },
      hill_chart_progress: { type: "integer", description: "Hill chart progress (0-100)" }
    },
    required: %w[name project_id]
  )

  def execute(name:, project_id:, description: nil, nice_to_have: false, hill_chart_progress: 0)
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
      "Scope created successfully!\n\n#{call_tool(GetScopeTool, scope_id: scope.id)}"
    else
      raise "Failed to create scope: #{scope.errors.full_messages.join(', ')}"
    end
  end
end
