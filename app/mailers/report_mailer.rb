class ReportMailer < ApplicationMailer
  # Send reminder email to user about pending report
  #
  # @param user [User] The user to send the reminder to
  # @param report_requirement [ReportRequirement] The report requirement
  # @param next_occurrence [Time] The date the report is due
  def reminder(user:, report_requirement:, next_occurrence:)
    @user = user
    @report_requirement = report_requirement
    @next_occurrence = next_occurrence
    @reportable = report_requirement.reportable.reportable

    subject = if report_requirement.reminder.negative?
      "PAST DUE: Report was due on #{next_occurrence.to_date}"
    else
      "Reminder: Report due on #{next_occurrence.to_date}"
    end

    Rails.logger.info("[ReportMailer] Sending reminder email to #{user.email} for requirement ##{report_requirement.id} (#{subject})")

    mail(
      to: user.email,
      subject: subject
    )
  end
end
