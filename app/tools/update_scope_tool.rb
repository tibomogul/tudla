# frozen_string_literal: true

class UpdateScopeTool < ApplicationTool
  description "Update an existing scope"

  annotations(
    title: "Update Scope",
    read_only_hint: false
  )

  input_schema(
    properties: {
      scope_id: { type: "integer", description: "ID of the scope to update" },
      name: { type: "string", description: "New name for the scope" },
      description: { type: "string", description: "New description for the scope" },
      nice_to_have: { type: "boolean", description: "Whether the scope is nice to have" },
      hill_chart_progress: { type: "integer", description: "Hill chart progress (0-100)" }
    },
    required: [ "scope_id" ]
  )

  def execute(scope_id:, **params)
    scopes = Scope.where(id: scope_id)
    scopes = scope_scopes_by_user(scopes)
    scope = scopes.first

    raise "Scope not found with ID: #{scope_id}" unless scope

    # Authorize using Pundit - user must have update permission
    authorize(scope, :update?)

    update_params = params.slice(:name, :description, :nice_to_have, :hill_chart_progress).compact

    if scope.update(update_params)
      "Scope updated successfully!\n\n#{call_tool(GetScopeTool, scope_id: scope.id)}"
    else
      raise "Failed to update scope: #{scope.errors.full_messages.join(', ')}"
    end
  end
end
