# Background job to post a report to Slack
class PostReportToSlackJob < ApplicationJob
  queue_as :default

  # Post a report to Slack based on its report requirement's delivery configuration
  #
  # @param report_id [Integer] The ID of the report to post
  def perform(report_id)
    Rails.logger.info("[PostReportToSlackJob] Starting job for report ##{report_id}")
    
    report = Report.find(report_id)
    
    # Find the report requirement to get delivery configuration
    report_requirement = ReportRequirement.find_by(
      reportable_id: report.reportable_id
    )
    
    unless report_requirement
      Rails.logger.warn("[PostReportToSlackJob] No report requirement found for report ##{report_id}")
      return
    end

    # Check if Slack posting is configured
    slack_service = SlackService.new(report, report_requirement)
    unless slack_service.slack_configured?
      Rails.logger.info("[PostReportToSlackJob] Slack not configured for report requirement ##{report_requirement.id}, skipping")
      return
    end

    # Post to Slack
    begin
      SlackService.post_report(report, report_requirement)
      Rails.logger.info("[PostReportToSlackJob] Successfully posted report ##{report_id} to Slack")
    rescue SlackService::SlackPostError => e
      Rails.logger.error("[PostReportToSlackJob] Failed to post report ##{report_id} to Slack: #{e.message}")
      raise # Re-raise to let Solid Queue handle retries
    end
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error("[PostReportToSlackJob] Report ##{report_id} not found: #{e.message}")
  rescue StandardError => e
    Rails.logger.error("[PostReportToSlackJob] Unexpected error for report ##{report_id}: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise
  end
end
