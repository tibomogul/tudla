# frozen_string_literal: true

class FetchPitchesTool < ApplicationTool
  description "Fetch pitches within a date range, filtered by organization or user"

  annotations(
    title: "Fetch Pitches",
    read_only_hint: true
  )

  input_schema(
    properties: {
      start_time: { type: "string", description: "Start datetime (ISO8601 format, e.g., '2025-11-03T00:00:00Z')" },
      end_time: { type: "string", description: "End datetime (ISO8601 format, e.g., '2025-11-04T00:00:00Z')" },
      organization_id: { type: "integer", description: "Filter pitches for a specific organization" },
      user_id: { type: "integer", description: "Filter to pitches authored by this user" },
      status: { type: "string", description: "Filter by status (draft, ready_for_betting, bet, rejected)" },
      limit: { type: "integer", description: "Maximum number of pitches to return (default: 100)" }
    },
    required: [ "start_time", "end_time" ]
  )

  def execute(start_time:, end_time:, organization_id: nil, user_id: nil, status: nil, limit: 100)
    start_datetime = parse_datetime(start_time)
    end_datetime = parse_datetime(end_time)

    raise "Invalid start_time format" unless start_datetime
    raise "Invalid end_time format" unless end_datetime
    raise "start_time must be before end_time" if start_datetime > end_datetime

    pitches = Pitch.active
    pitches = scope_pitches_by_user(pitches)

    pitches = pitches.where(created_at: start_datetime..end_datetime)

    pitches = pitches.where(organization_id: organization_id) if organization_id
    pitches = pitches.where(user_id: user_id) if user_id
    pitches = pitches.where(status: status) if status

    pitches = pitches.order(created_at: :desc).limit(limit)

    format_pitches(pitches)
  end

  private

  def parse_datetime(datetime_string)
    return nil if datetime_string.nil? || datetime_string.empty?

    Time.zone.parse(datetime_string)
  rescue ArgumentError
    nil
  end
end
