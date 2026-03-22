class Organizations::SettingsController < ApplicationController
  include OrganizationHierarchyFindable

  before_action :set_organization
  before_action :authorize_admin

  def show
  end

  def update
    if @organization.update(settings_params)
      redirect_to organization_settings_path(@organization), notice: "Settings updated successfully."
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def settings_params
    permitted = params.expect(organization: [ :llm_api_key, :llm_api_base, :llm_model, :clear_llm_settings ])

    if permitted.delete(:clear_llm_settings) == "1"
      return { llm_api_key: nil, llm_api_base: nil, llm_model: nil }
    end

    # Blank API key means "keep existing" — never clear it accidentally
    permitted.delete(:llm_api_key) if permitted[:llm_api_key].blank?
    permitted
  end
end
