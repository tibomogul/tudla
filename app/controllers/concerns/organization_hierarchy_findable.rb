module OrganizationHierarchyFindable
  extend ActiveSupport::Concern

  private

  def set_organization
    @organization = Organization.active.find(params[:organization_id])
  end

  def authorize_admin
    authorize @organization, :update?
  end

  def find_party_in_hierarchy(party_type, party_id)
    case party_type
    when "Organization"
      raise Pundit::NotAuthorizedError unless party_id.to_i == @organization.id
      @organization
    when "Team"
      @organization.teams.active.find(party_id)
    when "Project"
      team_ids = @organization.teams.active.pluck(:id)
      Project.active.where(team_id: team_ids).find(party_id)
    else
      raise Pundit::NotAuthorizedError
    end
  end

  def validate_role_in_hierarchy!(role)
    find_party_in_hierarchy(role.party_type, role.party_id)
  end
end
