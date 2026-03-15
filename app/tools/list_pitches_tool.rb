# frozen_string_literal: true

class ListPitchesTool < ApplicationTool
  description "List pitches accessible to the current user"

  annotations(
    title: "List Pitches",
    read_only_hint: true
  )

  input_schema(
    properties: {
      organization_id: { type: "integer", description: "Filter pitches for a specific organization" },
      status: { type: "string", description: "Filter by status (draft, ready_for_betting, bet, rejected)" },
      limit: { type: "integer", description: "Maximum number of pitches to return (default: 50)" }
    }
  )

  def execute(organization_id: nil, status: nil, limit: 50)
    pitches = Pitch.active
    pitches = scope_pitches_by_user(pitches)

    pitches = pitches.where(organization_id: organization_id) if organization_id
    pitches = pitches.where(status: status) if status

    pitches = pitches.order(created_at: :desc).limit(limit)

    format_pitches(pitches)
  end
end
