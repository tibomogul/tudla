# frozen_string_literal: true

class GetPitchTool < ApplicationTool
  description "Get detailed information about a specific pitch"

  annotations(
    title: "Get Pitch Details",
    read_only_hint: true
  )

  input_schema(
    properties: {
      pitch_id: { type: "integer", description: "ID of the pitch to retrieve" }
    },
    required: [ "pitch_id" ]
  )

  def execute(pitch_id:)
    pitches = Pitch.where(id: pitch_id)
    pitches = scope_pitches_by_user(pitches)
    pitch = pitches.first

    raise "Pitch not found with ID: #{pitch_id}" unless pitch

    format_pitch_details(pitch)
  end
end
