# frozen_string_literal: true

class ListReportsTool < ApplicationTool
  description "List reports accessible to the current user"

  annotations(
    title: "List Reports",
    read_only_hint: true
  )

  input_schema(
    properties: {
      project_id: { type: "integer", description: "Filter reports for a specific project" },
      team_id: { type: "integer", description: "Filter reports for a specific team or its projects" },
      submitted_only: { type: "boolean", description: "Only show submitted reports (default: true)" },
      limit: { type: "integer", description: "Maximum number of reports to return (default: 50)" }
    }
  )

  def execute(project_id: nil, team_id: nil, submitted_only: true, limit: 50)
    reports = Report.active
    reports = scope_reports_by_user(reports)

    if project_id
      reportable_ids = Reportable.where(reportable_type: "Project", reportable_id: project_id).select(:id)
      reports = reports.where(reportable_id: reportable_ids)
    end

    if team_id
      team = Team.find_by(id: team_id)
      raise "Team with ID #{team_id} not found" unless team

      team_reportable_ids = Reportable.where(reportable_type: "Team", reportable_id: team.id).select(:id)
      project_reportable_ids = Reportable.where(reportable_type: "Project", reportable_id: team.projects.active.select(:id)).select(:id)
      reports = reports.where(reportable_id: team_reportable_ids).or(reports.where(reportable_id: project_reportable_ids))
    end

    reports = reports.where.not(submitted_at: nil) if submitted_only

    reports = reports.order(as_of_at: :desc).limit(limit)

    format_reports(reports)
  end
end
