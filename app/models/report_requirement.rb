class ReportRequirement < ApplicationRecord
  belongs_to :reportable
  belongs_to :user

  # Validations
  validates :reminder, numericality: { only_integer: true, allow_nil: true }

  # Return the IceCube schedule object
  def ice_cube_schedule
    IceCube::Schedule.from_hash(schedule)
  end

  # Calculate the next occurrence from the schedule
  def next_occurrence(from_time = Time.current)
    ice_cube_schedule.next_occurrence(from_time)
  end

  # Calculate when the reminder should be sent
  # Returns nil if no reminder is set
  # reminder: 0 schedules at the exact next occurrence time
  def reminder_date(from_time = Time.current)
    return nil if reminder.blank?

    next_occ = next_occurrence(from_time)
    return nil unless next_occ

    next_occ - reminder.seconds
  end

  # Check if reminders are enabled for this requirement
  # Reminder is disabled only when nil
  def reminders_enabled?
    reminder.present?
  end
end
