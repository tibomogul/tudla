module Organizations::UsersHelper
  # Uses pre-computed @precomputed_hierarchy_ids to avoid N+1 queries.
  # Requires @precomputed_hierarchy_ids to be set by the controller before rendering.
  def role_in_org_hierarchy?(role)
    return false unless @precomputed_hierarchy_ids

    case role.party_type
    when "Organization" then role.party_id == @precomputed_hierarchy_ids[:org_id]
    when "Team" then @precomputed_hierarchy_ids[:team_ids].include?(role.party_id)
    when "Project" then @precomputed_hierarchy_ids[:project_ids].include?(role.party_id)
    else false
    end
  end

  def role_badge_label(role)
    prefix = case role.party_type
    when "Organization" then "Org"
    when "Team" then role.party.name
    when "Project" then role.party.name
    end
    "#{prefix}: #{role.role.capitalize}"
  end
end
