# frozen_string_literal: true

class ListUserChangesTool < ApplicationTool
  description "List changes from PaperTrail audit log (Tasks, Scopes, Projects, Notes, Links, Attachments). Shows current user's changes by default. " \
              "If team_id is specified, shows changes by all team members (user must be associated with team or its organization)."

  annotations(
    title: "List User Changes",
    read_only_hint: true
  )

  input_schema(
    properties: {
      start_time: { type: "string", description: "Start datetime (ISO8601 format, e.g., '2025-11-03T00:00:00Z'). Defaults to 24 hours ago." },
      end_time: { type: "string", description: "End datetime (ISO8601 format, e.g., '2025-11-04T00:00:00Z'). Defaults to now." },
      team_id: { type: "integer", description: "Show changes by all team members on team-related items (Tasks/Scopes/Projects/Notes/Links/Attachments in team's projects). Requires user to be associated with team or its organization." },
      limit: { type: "integer", description: "Maximum number of versions to return (default: 100)" }
    }
  )

  def execute(start_time: nil, end_time: nil, team_id: nil, limit: 100)
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

    # Add context for associated records (show what parent record they belong to)
    if %w[Note Link Attachment].include?(version.item_type)
      output += format_associated_record_context(version)
    end

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

  # Resolve the parent record context for Note, Link, or Attachment versions
  # All three use the same polymorphic pattern: record → join_table → parent
  def format_associated_record_context(version)
    mapping = {
      "Note" => { model: Note, association: :notable },
      "Link" => { model: Link, association: :linkable },
      "Attachment" => { model: Attachment, association: :attachable }
    }
    config = mapping[version.item_type]
    return "" unless config

    item = config[:model].unscoped.find_by(id: version.item_id)
    return "" unless item

    join_record = item.public_send(config[:association])
    return "" unless join_record&.public_send(config[:association])

    record = join_record.public_send(config[:association])
    parent_name = record.respond_to?(:name) ? record.name : record.respond_to?(:title) ? record.title : nil
    context = "Parent: #{record.class.name} ##{record.id}"
    context += " (#{parent_name})" if parent_name.present?
    context + "\n"
  end

  # Filter versions to only include changes related to the team.
  # Uses relation subqueries (.select(:id)) so the DB does all the heavy
  # lifting in a single query — no IDs are materialised into Ruby.
  # Respects .active (soft-delete) on every model that supports it.
  def filter_by_team(versions, team)
    project_rel = team.projects.active
    return versions.none unless project_rel.exists?

    project_ids = project_rel.select(:id)
    task_rel    = Task.active.where(project_id: project_ids).select(:id)
    scope_rel   = Scope.active.where(project_id: project_ids).select(:id)

    # Resolve Notes/Links/Attachments via their polymorphic join tables
    parent_map = { "Task" => task_rel, "Scope" => scope_rel, "Project" => project_ids }
    note_rel       = polymorphic_item_rel(Notable,    :notable,    parent_map, Note,       :notable_id)
    link_rel       = polymorphic_item_rel(Linkable,   :linkable,   parent_map, Link,       :linkable_id)
    attachment_rel = polymorphic_item_rel(Attachable, :attachable, parent_map, Attachment, :attachable_id)

    # Build a single OR via Arel so the base versions conditions are not
    # duplicated across branches — produces clean, EXPLAINable SQL.
    vt = PaperTrail::Version.arel_table
    type_rels = {
      "Task" => task_rel, "Scope" => scope_rel, "Project" => project_ids,
      "Note" => note_rel, "Link" => link_rel, "Attachment" => attachment_rel
    }

    arel_or = type_rels.map { |type, rel|
      vt[:item_type].eq(type).and(vt[:item_id].in(rel.arel))
    }.reduce(:or) || vt[:id].eq(nil)

    versions.where(arel_or)
  end

  # Build a relation subquery for a polymorphic association
  # (Note→Notable, Link→Linkable, Attachment→Attachable).
  # Returns an ActiveRecord::Relation with .select(:id) — never materialised.
  # Join tables (Notable/Linkable/Attachable) have no soft-delete column;
  # .active is applied only on the leaf item model.
  def polymorphic_item_rel(join_model, prefix, parent_map, item_model, fk)
    type_col = :"#{prefix}_type"
    id_col   = :"#{prefix}_id"

    scopes = parent_map.map { |type, rel|
      join_model.where(type_col => type, id_col => rel)
    }

    return item_model.none.select(:id) if scopes.empty?

    join_rel = scopes.reduce(:or).select(:id)
    item_model.active.where(fk => join_rel).select(:id)
  end
end
