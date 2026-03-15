# frozen_string_literal: true

class FetchReportsTool < ApplicationTool
  description "Fetch reports within a date range, filtered by team or user"

  annotations(
    title: "Fetch Reports",
    read_only_hint: true
  )

  input_schema(
    properties: {
      start_time: { type: "string", description: "Start datetime (ISO8601 format, e.g., '2025-11-03T00:00:00Z')" },
      end_time: { type: "string", description: "End datetime (ISO8601 format, e.g., '2025-11-04T00:00:00Z')" },
      team_id: { type: "integer", description: "Filter to reports on the team or its projects" },
      user_id: { type: "integer", description: "Filter to reports authored by this user" },
      submitted_only: { type: "boolean", description: "Only show submitted reports (default: true)" },
      limit: { type: "integer", description: "Maximum number of reports to return (default: 100)" }
    },
    required: [ "start_time", "end_time" ]
  )

  def execute(start_time:, end_time:, team_id: nil, user_id: nil, submitted_only: true, limit: 100)
    start_datetime = parse_datetime(start_time)
    end_datetime = parse_datetime(end_time)

    raise "Invalid start_time format" unless start_datetime
    raise "Invalid end_time format" unless end_datetime
    raise "start_time must be before end_time" if start_datetime > end_datetime

    reports = Report.active
    reports = scope_reports_by_user(reports)

    reports = reports.where(as_of_at: start_datetime..end_datetime)

    if team_id
      team = Team.find_by(id: team_id)
      raise "Team with ID #{team_id} not found" unless team

      unless user_authorized_for_team?(team)
        raise "Not authorized to view reports for Team #{team_id}. " \
              "You must be associated with the team or its organization."
      end

      team_reportable_ids = Reportable.where(reportable_type: "Team", reportable_id: team.id).select(:id)
      project_reportable_ids = Reportable.where(reportable_type: "Project", reportable_id: team.projects.active.select(:id)).select(:id)
      reports = reports.where(reportable_id: team_reportable_ids).or(reports.where(reportable_id: project_reportable_ids))
    end

    reports = reports.where(user_id: user_id) if user_id

    reports = reports.where.not(submitted_at: nil) if submitted_only

    reports = reports.order(as_of_at: :desc).limit(limit)

    format_reports(reports)
  end

  private

  def parse_datetime(datetime_string)
    return nil if datetime_string.nil? || datetime_string.empty?

    Time.zone.parse(datetime_string)
  rescue ArgumentError
    nil
  end

  def user_authorized_for_team?(team)
    UserPartyRole.exists?(
      user_id: current_user.id,
      party_type: "Team",
      party_id: team.id
    ) || UserPartyRole.exists?(
      user_id: current_user.id,
      party_type: "Organization",
      party_id: team.organization_id
    )
  end
end
