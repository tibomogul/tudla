class Organizations::UserPartyRolesController < ApplicationController
  include OrganizationHierarchyFindable

  before_action :set_organization
  before_action :authorize_admin

  def create
    user = User.find(params[:user_id])
    party = find_party_in_hierarchy(params[:party_type], params[:party_id])

    existing = UserPartyRole.find_by(user: user, party: party)
    if existing&.role == params[:role]
      redirect_to organization_users_path(@organization),
                  alert: "#{user.email} already has the #{params[:role]} role for #{party.name}."
      return
    end

    role = existing || UserPartyRole.new(user: user, party: party)
    role.role = params[:role]
    role.save!

    redirect_to organization_users_path(@organization),
                notice: "Role updated for #{user.email}."
  end

  def update
    role = UserPartyRole.find(params[:id])
    validate_role_in_hierarchy!(role)
    role.update!(role: params[:role])
    redirect_to organization_users_path(@organization),
                notice: "Role updated for #{role.user.email}."
  end

  def destroy
    role = UserPartyRole.find(params[:id])
    validate_role_in_hierarchy!(role)
    email = role.user.email
    role.destroy!

    redirect_to organization_users_path(@organization),
                notice: "Role removed for #{email}."
  end
end
