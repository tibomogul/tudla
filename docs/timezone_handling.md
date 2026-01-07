# Timezone Handling

This document describes how the application handles timezones to ensure all time display and editing respects the Organization's timezone.

## Overview

The application uses the Organization's timezone for all time-related operations. Each Organization has a `timezone` field (defaults to "Australia/Brisbane") that determines how times are displayed and interpreted throughout the application.

## Database Schema

```ruby
# organizations table
t.string :timezone, default: "Australia/Brisbane", null: false
```

## Model Hierarchy

```
Organization
  └── Team
      └── Project
          └── Task
          └── Reportable
              └── Report
```

## Implementation

### Organization Model

The Organization model stores the timezone:

```ruby
class Organization < ApplicationRecord
  # timezone column (string)
end
```

### Task Model

Tasks get their timezone through their Project:

```ruby
class Task < ApplicationRecord
  # Get the organization from the task's project
  def organization
    project&.team&.organization
  end

  # Get the organization's timezone or default
  def timezone
    organization&.timezone || "Australia/Brisbane"
  end

  # Format a datetime in the organization's timezone
  def format_in_timezone(datetime, format = "%d %b %H:%M")
    return nil unless datetime
    datetime.in_time_zone(timezone).strftime(format)
  end
end
```

### Project Model

Projects get their timezone through their Team:

```ruby
class Project < ApplicationRecord
  # Get the organization from the project's team
  def organization
    team&.organization
  end

  # Get the organization's timezone or default
  def timezone
    organization&.timezone || "Australia/Brisbane"
  end

  # Format a datetime in the organization's timezone
  def format_in_timezone(datetime, format = "%d %b %H:%M")
    return nil unless datetime
    datetime.in_time_zone(timezone).strftime(format)
  end
end
```

### Report Model

Reports get their timezone through their Reportable (Project or Team):

```ruby
class Report < ApplicationRecord
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
```

## View Usage

### Displaying Times

Use the model's `format_in_timezone` method to display times:

```erb
<!-- Task transitions -->
<%= transition.task.format_in_timezone(transition.created_at) %>

<!-- Project risk transitions -->
<%= transition.project.format_in_timezone(transition.created_at) %>

<!-- Reports -->
<%= @report.format_in_timezone(@report.as_of_at, :long_ordinal) %>
<span class="text-xs">(<%= @report.timezone %>)</span>
```

### Editing Times

For datetime input fields, convert to organization timezone:

```erb
<% 
  # Convert to organization timezone for display in form
  display_value = if report.as_of_at && report.reportable
    report.as_of_at.in_time_zone(report.timezone)
  else
    report.as_of_at
  end
%>
<%= form.datetime_local_field :as_of_at, 
    value: display_value&.strftime("%Y-%m-%dT%H:%M") %>
<p class="text-xs">Times are in <%= report.timezone %></p>
```

## Controller Handling

### ReportsController

The `ReportsController` includes several timezone-aware helper methods:

#### Default Times

```ruby
def new
  # Default to current time in organization timezone
  @report.as_of_at ||= current_time_in_organization_timezone(@report)
end

def current_time_in_organization_timezone(report)
  return Time.current unless report.reportable
  
  organization = get_organization_from_reportable(report.reportable)
  timezone = organization&.timezone || "Australia/Brisbane"
  Time.current.in_time_zone(timezone)
end
```

#### Parsing Form Input

```ruby
def create
  @report = Report.new(report_params)
  @report.user = current_user
  
  # Parse as_of_at in organization timezone
  parse_as_of_at_in_timezone(@report)
  
  # ... save report
end

def parse_as_of_at_in_timezone(report)
  return unless report.as_of_at_changed? && report.as_of_at.present?
  return unless report.reportable

  organization = get_organization_from_reportable(report.reportable)
  timezone_name = organization&.timezone || "Australia/Brisbane"
  
  # The as_of_at value from the form is parsed by Rails (usually as UTC or app default timezone)
  # We need to interpret those date/time components as being in the organization's timezone
  # Best practice: use ActiveSupport::TimeZone to parse in the correct timezone
  local_time = report.as_of_at
  tz = ActiveSupport::TimeZone[timezone_name]
  report.as_of_at = tz.parse(local_time.strftime('%Y-%m-%d %H:%M:%S'))
end
```

**Key Points:**
- `datetime_local_field` sends datetime without timezone information
- Rails initially parses this as UTC (or the app's default timezone)
- We extract the date/time components and reparse them using `ActiveSupport::TimeZone[timezone_name].parse()`
- This correctly interprets "9:00 AM" as 9:00 AM in the organization's timezone, not UTC

#### Schedule Calculations

```ruby
def calculate_as_of_at(reportable)
  # Get organization timezone
  organization = get_organization_from_reportable(reportable)
  timezone = organization&.timezone || "Australia/Brisbane"
  current_time_in_tz = Time.current.in_time_zone(timezone)

  # Use current_time_in_tz for schedule calculations
  requirement.next_occurrence(current_time_in_tz)
end
```

## SlackService

The `SlackService` formats dates in organization timezone when posting reports:

```ruby
class SlackService
  def format_date_in_timezone(datetime)
    return "Unknown" if datetime.blank?

    organization = get_organization
    timezone = organization&.timezone || "Australia/Brisbane"

    datetime.in_time_zone(timezone).strftime("%B %d, %Y")
  end

  def get_organization
    reportable = @report_requirement.reportable.reportable
    return nil unless reportable

    case reportable.class.name
    when "Project"
      reportable.team&.organization
    when "Team"
      reportable.organization
    else
      nil
    end
  end
end
```

## Views Updated

The following views have been updated to respect organization timezone:

### Reports
- `app/views/reports/_form.html.erb` - Form with timezone indicator and proper parsing
- `app/views/reports/show.html.erb` - Display with timezone indicator
- `app/views/reports/index.html.erb` - List view with formatted times
- `app/views/shared/_recent_reports.html.erb` - Recent reports display

### Tasks
- `app/views/tasks/_transition.html.erb` - Task state transition history

### Projects
- `app/views/projects/_risk_transition.html.erb` - Project risk transition history

## Testing

To test timezone handling:

1. Create or update an Organization with a specific timezone:
   ```ruby
   org = Organization.find_or_create_by(name: "Test Org")
   org.update(timezone: "America/New_York")
   ```

2. Create a Report for a Project in that Organization

3. Verify times are displayed in the specified timezone:
   - Report form should show "(America/New_York)" in the label
   - Report show page should display times in America/New_York
   - Task transitions should display in America/New_York

## Common Pitfalls & Best Practices

### ❌ Wrong: Appending timezone to string
```ruby
# DON'T DO THIS
Time.zone.parse("#{datetime_string} #{timezone}")
```
This doesn't work correctly because the timezone is appended to the end, not used to interpret the datetime components.

### ✅ Correct: Use ActiveSupport::TimeZone
```ruby
# DO THIS
tz = ActiveSupport::TimeZone[timezone_name]
tz.parse(datetime_string)
```
This correctly interprets the datetime string as being in that timezone.

### ❌ Wrong: Using class constants in case statements
```ruby
# DON'T DO THIS - causes autoloading issues
case reportable
when Project
  # ...
```

### ✅ Correct: Use string class names
```ruby
# DO THIS
case reportable.class.name
when "Project"
  # ...
```

### Best Practices Summary
1. **Always use `ActiveSupport::TimeZone`** for timezone-aware parsing
2. **Store times in UTC** in the database (Rails default)
3. **Convert to organization timezone** at the view/controller layer
4. **Use string class names** in case statements to avoid autoloading issues
5. **Show timezone indicators** in UI so users know which timezone is being used
6. **Test with different timezones** to catch offset errors

## Future Enhancements

Potential improvements:
- Add timezone selector to Organization form
- Display user's local time alongside organization time
- Allow users to set their preferred timezone for display
- Add timezone conversion utilities for API responses

## Notes

- All datetimes are stored in UTC in the database
- Timezone conversion happens at the view/controller layer
- The default timezone is "Australia/Brisbane"
- Each model (Task, Project, Report) provides its own `timezone` method
- The `format_in_timezone` method is consistent across models
