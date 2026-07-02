class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :custom_authenticate_user!, unless: :devise_controller?
  before_action :configure_permitted_parameters, if: :devise_controller?

  before_action :set_paper_trail_whodunnit
  before_action :set_pulse_actor

  include Pundit::Authorization
  include ActionView::RecordIdentifier
  include Pagy::Method

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  protected

  # Attribute Pulse events to the signed-in user. McpController overrides the
  # actor with type "agent" after Bearer-token auth; jobs/console fall back to
  # the "system" actor via Pulse::Current defaults.
  def set_pulse_actor
    Pulse::Current.user = current_user if user_signed_in?
  end

  def configure_permitted_parameters
    update_attrs = [ :password, :password_confirmation, :current_password ]
    devise_parameter_sanitizer.permit :account_update, keys: update_attrs
  end

  helper_method :current_organization, :current_admin_organization

  def current_organization
    return nil unless user_signed_in?
    @current_organization ||= begin
      orgs = current_user.accessible_organizations
      if session[:current_organization_id]
        orgs.find { |o| o.id == session[:current_organization_id] } || orgs.first
      else
        orgs.first
      end
    end
  end

  def current_admin_organization
    return nil unless current_organization
    @current_admin_organization ||= begin
      admin_org_ids = current_user.user_party_roles
        .where(party_type: "Organization", role: "admin")
        .pluck(:party_id)
      current_organization if admin_org_ids.include?(current_organization.id)
    end
  end

  helper_method :current_organization_team_ids, :current_organization_project_ids

  def current_organization_team_ids
    return [] unless current_organization
    @current_organization_team_ids ||= current_organization.teams.active.pluck(:id)
  end

  def current_organization_project_ids
    return [] unless current_organization
    @current_organization_project_ids ||= Project.active.where(team_id: current_organization_team_ids).pluck(:id)
  end

  def custom_authenticate_user!
    redirect_to root_path, notice: "You must login" unless user_signed_in?
  end

  private

  def user_not_authorized
    respond_to do |format|
      format.html { redirect_back_or_to(root_path, alert: "You are not authorized to perform this action.") }
      format.json { render json: { error: "Not authorized", error_code: "not_authorized" }, status: :forbidden }
      format.any  { head :forbidden }
    end
  end
end
