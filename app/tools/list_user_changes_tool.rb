# frozen_string_literal: true

class ListUserChangesTool < ApplicationTool
  description "List changes from PaperTrail audit log. Shows current user's changes by default. " \
              "If team_id is specified, shows changes by all team members (user must be associated with team or its organization)."

  annotations(
    title: "List User Changes",
    read_only_hint: true
  )

  arguments do
    optional(:start_time).filled(:string).description("Start datetime (ISO8601 format, e.g., '2025-11-03T00:00:00Z'). Defaults to 24 hours ago.")
    optional(:end_time).filled(:string).description("End datetime (ISO8601 format, e.g., '2025-11-04T00:00:00Z'). Defaults to now.")
    optional(:team_id).filled(:integer).description("Show changes by all team members on team-related items (Tasks/Scopes/Projects in team's projects). Requires user to be associated with team or its organization.")
    optional(:limit).filled(:integer).description("Maximum number of versions to return (default: 100)")
  end

  def call(start_time: nil, end_time: nil, team_id: nil, limit: 100)
    # Parse datetime parameters with defaults
    end_datetime = parse_datetime(end_time) || Time.current
    start_datetime = parse_datetime(start_time) || 24.hours.ago

    # Validate datetime range
    if start_datetime > end_datetime
      raise "start_time must be before end_time"
    end

    # Authorize team access if team_id is provided
    team = nil
    if team_id
      team = Team.find_by(id: team_id)
      raise "Team with ID #{team_id} not found" unless team
      
      # Check if user is associated with team or its organization
      unless user_authorized_for_team?(team)
        raise "Not authorized to view changes for Team #{team_id}. " \
              "You must be associated with the team or its organization."
      end
    end

    # Query versions - filter by team users if team specified, otherwise current user only
    if team
      # Get all users associated with the team
      team_user_ids = team.users.pluck(:id).map(&:to_s)
      versions = PaperTrail::Version
        .where(whodunnit: team_user_ids)
        .where(created_at: start_datetime..end_datetime)
        .order(created_at: :desc)
      
      # Filter by team-related items
      versions = filter_by_team(versions, team)
    else
      # Show only current user's changes
      versions = PaperTrail::Version
        .where(whodunnit: current_user.id.to_s)
        .where(created_at: start_datetime..end_datetime)
        .order(created_at: :desc)
    end

    versions = versions.limit(limit)

    format_versions(versions, start_datetime, end_datetime, team)
  end

  private

  def parse_datetime(datetime_string)
    return nil if datetime_string.nil? || datetime_string.empty?

    Time.zone.parse(datetime_string)
  rescue ArgumentError
    nil
  end

  def format_versions(versions, start_datetime, end_datetime, team = nil)
    return format_no_versions(start_datetime, end_datetime, team) if versions.empty?

    if team
      output = "Found #{versions.count} change(s) by Team '#{team.name}' members "
    else
      output = "Found #{versions.count} change(s) by #{format_user(current_user)} "
    end
    output += "between #{format_datetime(start_datetime)} and #{format_datetime(end_datetime)}:\n\n"

    versions.each do |version|
      output += format_version(version)
      output += "\n---\n\n"
    end

    output
  end

  def format_no_versions(start_datetime, end_datetime, team = nil)
    if team
      output = "No changes found by Team '#{team.name}' members "
    else
      output = "No changes found by #{format_user(current_user)} "
    end
    output += "between #{format_datetime(start_datetime)} and #{format_datetime(end_datetime)}."
    output
  end

  def format_version(version)
    # Get user who made the change
    user = User.find_by(id: version.whodunnit)
    user_info = user ? format_user(user) : "User ID #{version.whodunnit}"
    
    output = <<~TEXT
      Timestamp: #{format_datetime(version.created_at)}
      User: #{user_info}
      Action: #{version.event}
      Item Type: #{version.item_type}
      Item ID: #{version.item_id}
    TEXT

    if version.object_changes.present?
      output += "\nChanges:\n"
      output += format_object_changes(version.object_changes)
    end

    output
  end

  def format_object_changes(object_changes)
    return "  (No changes recorded)\n" if object_changes.blank?

    output = ""
    object_changes.each do |attribute, changes|
      output += "  #{attribute}:\n"
      changes.each do |change|
        output += format_hashdiff_change(change, indent: 4)
      end
    end
    output
  end

  def format_hashdiff_change(change, indent: 0)
    operator, path, *values = change
    indent_str = " " * indent

    case operator
    when "~" # Modified
      old_value, new_value = values
      path_str = format_path(path)
      "#{indent_str}Modified #{path_str}: #{format_value(old_value)} → #{format_value(new_value)}\n"
    when "+" # Added
      value = values.first
      path_str = format_path(path)
      "#{indent_str}Added #{path_str}: #{format_value(value)}\n"
    when "-" # Removed
      value = values.first
      path_str = format_path(path)
      "#{indent_str}Removed #{path_str}: #{format_value(value)}\n"
    else
      "#{indent_str}Unknown change: #{change.inspect}\n"
    end
  end

  def format_path(path)
    return "value" if path.empty?

    path.map { |segment| "[#{segment}]" }.join
  end

  def format_value(value)
    case value
    when nil
      "nil"
    when String
      value.length > 100 ? "\"#{value[0...97]}...\"" : "\"#{value}\""
    when Hash
      value.inspect.length > 100 ? "{...}" : value.inspect
    when Array
      value.inspect.length > 100 ? "[...]" : value.inspect
    else
      value.to_s
    end
  end

  # Check if current user is authorized to view team changes
  # User must be associated with the team or its organization via UserPartyRole
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

  # Filter versions to only include changes related to the team
  # This includes:
  # - Tasks that belong to projects in the team
  # - Scopes that belong to projects in the team
  # - Projects that belong to the team
  def filter_by_team(versions, team)
    # Get all project IDs for the team
    project_ids = team.projects.pluck(:id)
    
    # Filter versions where:
    # 1. Item is a Task with project_id in team's projects
    # 2. Item is a Scope with project_id in team's projects
    # 3. Item is a Project with id in team's projects
    versions.where(
      "(item_type = 'Task' AND item_id IN (SELECT id FROM tasks WHERE project_id IN (?))) OR " \
      "(item_type = 'Scope' AND item_id IN (SELECT id FROM scopes WHERE project_id IN (?))) OR " \
      "(item_type = 'Project' AND item_id IN (?))",
      project_ids, project_ids, project_ids
    )
  end
end
