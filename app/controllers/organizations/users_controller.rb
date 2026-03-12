class Organizations::UsersController < ApplicationController
  include OrganizationHierarchyFindable

  before_action :set_organization
  before_action :authorize_admin

  def index
    users = @organization.members.includes(user_party_roles: :party).order(:email)
    if params[:user_name].present?
      users = users.where("users.email ILIKE ? OR users.preferred_name ILIKE ?",
                          "%#{params[:user_name]}%", "%#{params[:user_name]}%")
    end
    @pagy_users, @users = pagy(:offset, users, limit: 20)
    @precomputed_hierarchy_ids = org_hierarchy_ids # pre-compute for view helper
    @teams = @organization.teams.active.includes(:projects).order(:name)
    @existing_role_keys_by_user = @organization.hierarchy_roles
                                               .where(user: @users)
                                               .pluck(:user_id, :party_type, :party_id, :role)
                                               .group_by(&:first)
                                               .transform_values { |rows| rows.map { |_, type, id, role| "#{type}-#{id}-#{role}" } }

    if turbo_frame_request_id == "users_index_list"
      render partial: "organizations/users/users_index_content",
             locals: { pagy_users: @pagy_users, users: @users, organization: @organization,
                       existing_role_keys_by_user: @existing_role_keys_by_user, teams: @teams }
    end
  end

  def new
    @teams = @organization.teams.active.includes(:projects).order(:name)
  end

  def lookup
    email = params[:email]&.strip&.downcase
    user = User.find_by(email: email) if email.present?

    if user
      existing_party_keys = @organization.hierarchy_roles
                                         .where(user: user)
                                         .pluck(:party_type, :party_id)
                                         .map { |type, id| "#{type}-#{id}" }
      render json: {
        found: true,
        username: user.username,
        preferred_name: user.preferred_name,
        existing_party_keys: existing_party_keys
      }
    else
      render json: { found: false }
    end
  end

  def create
    email = params[:email]&.strip&.downcase
    role = params[:role].presence || "member"

    if email.blank?
      redirect_to organization_users_path(@organization), alert: "Email is required."
      return
    end

    party = find_party_in_hierarchy(params[:party_type].presence || "Organization",
                                    params[:party_id].presence || @organization.id)

    existing_user = User.find_by(email: email)

    if existing_user && UserPartyRole.exists?(user: existing_user, party: party)
      redirect_to new_organization_user_path(@organization),
                  alert: "#{email} already has a role for this #{party.model_name.human.downcase}."
      return
    end

    if existing_user
      user = existing_user
    else
      user = User.invite!(
        {
          email: email,
          username: params[:username].presence,
          preferred_name: params[:preferred_name].presence
        },
        current_user
      )
      unless user.persisted?
        redirect_to new_organization_user_path(@organization),
                    alert: "Could not invite user: #{user.errors.full_messages.join(', ')}"
        return
      end
    end

    UserPartyRole.create!(user: user, party: party, role: role)
    OrganizationMailer.user_added(user: user, party: party, added_by: current_user).deliver_later if existing_user

    redirect_to organization_users_path(@organization), notice: "User #{email} has been invited."
  end

  def destroy
    user = @organization.members.find(params[:id])

    if user == current_user
      redirect_to organization_users_path(@organization), alert: "You cannot remove yourself."
      return
    end

    @organization.hierarchy_roles.where(user: user).destroy_all

    unless UserPartyRole.where(user: user).exists?
      user.lock_access!(send_instructions: false) unless user.access_locked?
      user.soft_delete
    end

    redirect_to organization_users_path(@organization),
                notice: "#{user.email} has been removed from the organization."
  end

  def lock
    user = @organization.members.find(params[:id])
    if user == current_user
      redirect_to organization_users_path(@organization), alert: "You cannot lock your own account."
      return
    end
    user.lock_access!(send_instructions: false)
    redirect_to organization_users_path(@organization), notice: "#{user.email} has been disabled."
  end

  def unlock
    user = @organization.members.find(params[:id])
    user.unlock_access!
    redirect_to organization_users_path(@organization), notice: "#{user.email} has been enabled."
  end

  private

  def org_hierarchy_ids
    @org_hierarchy_ids ||= @organization.hierarchy_ids
  end
end
