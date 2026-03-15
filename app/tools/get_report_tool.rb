# frozen_string_literal: true

class GetReportTool < ApplicationTool
  description "Get detailed information about a specific report"

  annotations(
    title: "Get Report Details",
    read_only_hint: true
  )

  input_schema(
    properties: {
      report_id: { type: "integer", description: "ID of the report to retrieve" }
    },
    required: [ "report_id" ]
  )

  def execute(report_id:)
    reports = Report.where(id: report_id)
    reports = scope_reports_by_user(reports)
    report = reports.first

    raise "Report not found with ID: #{report_id}" unless report

    format_report_details(report)
  end
end
