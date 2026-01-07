class ReportRequirementReminderScheduler
  # Schedule reminder jobs for all active report requirements
  #
  # @return [Hash] Statistics about scheduled jobs
  def self.call
    new.call
  end

  def call
    Rails.logger.info("[ReportRequirementReminderScheduler] Starting reminder scheduling run")
    stats = { scheduled: 0, skipped: 0, errors: 0 }

    requirements = active_requirements
    Rails.logger.info("[ReportRequirementReminderScheduler] Found #{requirements.count} active report requirements")

    requirements.find_each do |requirement|
      process_requirement(requirement, stats)
    rescue StandardError => e
      Rails.logger.error("[ReportRequirementReminderScheduler] Error processing report requirement #{requirement.id}: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      stats[:errors] += 1
    end

    Rails.logger.info("[ReportRequirementReminderScheduler] Completed: #{stats[:scheduled]} scheduled, #{stats[:skipped]} skipped, #{stats[:errors]} errors")
    stats
  end

  private

  def active_requirements
    # Find all report requirements with a reminder value set (not nil)
    # reminder: 0 is valid and schedules at exact next occurrence time
    ReportRequirement.where.not(reminder: nil)
  end

  def process_requirement(requirement, stats)
    Rails.logger.debug("[ReportRequirementReminderScheduler] Processing requirement ##{requirement.id} (reminder: #{requirement.reminder}s)")
    
    next_occurrence = calculate_next_occurrence(requirement)
    unless next_occurrence
      Rails.logger.warn("[ReportRequirementReminderScheduler] No next occurrence found for requirement ##{requirement.id}")
      return
    end

    reminder_date = next_occurrence - requirement.reminder.seconds
    Rails.logger.debug("[ReportRequirementReminderScheduler] Requirement ##{requirement.id}: next_occurrence=#{next_occurrence}, reminder_date=#{reminder_date}")

    # Only schedule if reminder date is in the future
    unless reminder_date > Time.current
      Rails.logger.info("[ReportRequirementReminderScheduler] Skipping requirement ##{requirement.id}: reminder date #{reminder_date} is in the past")
      stats[:skipped] += 1
      return
    end

    # Check if job already scheduled
    if job_already_scheduled?(requirement.id, next_occurrence)
      Rails.logger.info("[ReportRequirementReminderScheduler] Skipping requirement ##{requirement.id}: job already scheduled for #{next_occurrence}")
      stats[:skipped] += 1
      return
    end

    # Schedule the job
    ReportRequirementReminderJob.set(wait_until: reminder_date).perform_later(
      requirement.id,
      next_occurrence
    )
    Rails.logger.info("[ReportRequirementReminderScheduler] Scheduled job for requirement ##{requirement.id} at #{reminder_date} (occurrence: #{next_occurrence})")

    stats[:scheduled] += 1
  end

  def calculate_next_occurrence(requirement)
    schedule = requirement.ice_cube_schedule
    schedule.next_occurrence(Time.current)
  rescue StandardError => e
    Rails.logger.error("[ReportRequirementReminderScheduler] Error calculating next occurrence for requirement #{requirement.id}: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    nil
  end

  def job_already_scheduled?(report_requirement_id, next_occurrence)
    # Query Solid Queue jobs table to check if job already exists
    # We check for jobs that:
    # - Are of class ReportRequirementReminderJob
    # - Have matching arguments (report_requirement_id and next_occurrence)
    # - Haven't finished yet (finished_at is nil)

    # The arguments column contains JSON with nested 'arguments' array
    # We need to check if the first argument matches report_requirement_id
    # and the second argument (TimeSerializer) matches next_occurrence
    
    # Format the time the same way ActiveJob does
    serialized_time = next_occurrence.iso8601(9)

    SolidQueue::Job.where(
      class_name: "ReportRequirementReminderJob",
      finished_at: nil
    ).where(
      "arguments::jsonb -> 'arguments' -> 0 = ? AND arguments::jsonb -> 'arguments' -> 1 -> 'value' = ?",
      report_requirement_id.to_json,
      serialized_time.to_json
    ).exists?
  rescue StandardError => e
    # If there's an error checking (e.g., table structure changed), log and default to false
    Rails.logger.warn("[ReportRequirementReminderScheduler] Error checking scheduled jobs: #{e.message}")
    false
  end
end
