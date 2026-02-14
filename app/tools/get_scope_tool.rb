# frozen_string_literal: true

class GetScopeTool < ApplicationTool
  description "Get detailed information about a specific scope"

  annotations(
    title: "Get Scope Details",
    read_only_hint: true
  )

  input_schema(
    properties: {
      scope_id: { type: "integer", description: "ID of the scope to retrieve" }
    },
    required: [ "scope_id" ]
  )

  def execute(scope_id:)
    scopes = Scope.where(id: scope_id)
    scopes = scope_scopes_by_user(scopes)
    scope = scopes.first

    raise "Scope not found with ID: #{scope_id}" unless scope

    format_scope_details(scope)
  end
end
