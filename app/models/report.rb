class Report < ApplicationRecord
  include SoftDeletable
  belongs_to :reportable
  belongs_to :user

  # Check if report has been submitted
  def submitted?
    submitted_at.present?
  end

  # Check if report can be edited
  def editable?
    !submitted?
  end

  # Get the organization from the reportable (works for Project or Team)
  def organization
    return nil unless reportable&.reportable

    case reportable.reportable.class.name
    when "Project"
      reportable.reportable.team&.organization
    when "Team"
      reportable.reportable.organization
    else
      nil
    end
  end

  # Get the organization's timezone or default
  def timezone
    organization&.timezone || "Australia/Brisbane"
  end

  # Format a datetime in the organization's timezone
  def format_in_timezone(datetime, format = :long_ordinal)
    return nil unless datetime
    datetime.in_time_zone(timezone).to_formatted_s(format)
  end
end
