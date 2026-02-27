module OrganizationScoping
  extend ActiveSupport::Concern

  private

  def load_accessible_organizations
    @organization_ids = UserPartyRole
      .where(user: current_user, party_type: "Organization")
      .pluck(:party_id)
    @organizations = Organization.active.where(id: @organization_ids).order(:name)
  end
end
