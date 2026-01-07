class ReportRequirementReminderJob < ApplicationJob
  queue_as :default

  # Send reminder emails to users who haven't submitted their reports
  #
  # @param report_requirement_id [Integer] The ID of the report requirement
  # @param next_occurrence [Time] The date the report is due
  def perform(report_requirement_id, next_occurrence)
    Rails.logger.info("[ReportRequirementReminderJob] Starting job for requirement ##{report_requirement_id}, occurrence: #{next_occurrence}")
    
    report_requirement = ReportRequirement.find(report_requirement_id)
    next_occurrence = next_occurrence.to_time

    # Get the actual reportable entity (Project or Team)
    reportable_entity = report_requirement.reportable.reportable
    Rails.logger.info("[ReportRequirementReminderJob] Reportable: #{reportable_entity.class.name} ##{reportable_entity.id} (#{reportable_entity.name})")

    # Find all users associated with the reportable entity via user_party_roles
    user_ids = UserPartyRole.where(
      party_type: reportable_entity.class.name,
      party_id: reportable_entity.id
    ).pluck(:user_id).uniq

    users = User.where(id: user_ids)
    Rails.logger.info("[ReportRequirementReminderJob] Found #{users.count} users associated with #{reportable_entity.class.name} ##{reportable_entity.id}")

    reminders_sent = 0
    reports_exist = 0

    # Check each user for existing report
    users.each do |user|
      # Check if user already has a report for this occurrence
      existing_report = Report.exists?(
        reportable_id: report_requirement.reportable_id,
        user_id: user.id,
        as_of_at: next_occurrence
      )

      if existing_report
        Rails.logger.debug("[ReportRequirementReminderJob] User ##{user.id} (#{user.username}) already has report for #{next_occurrence}")
        reports_exist += 1
      else
        Rails.logger.info("[ReportRequirementReminderJob] Sending reminder to user ##{user.id} (#{user.username})")
        ReportMailer.reminder(
          user: user,
          report_requirement: report_requirement,
          next_occurrence: next_occurrence
        ).deliver_later
        reminders_sent += 1
      end
    end

    Rails.logger.info("[ReportRequirementReminderJob] Completed: #{reminders_sent} reminders sent, #{reports_exist} users already submitted")
  rescue StandardError => e
    Rails.logger.error("[ReportRequirementReminderJob] Error processing requirement ##{report_requirement_id}: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise
  end
end
