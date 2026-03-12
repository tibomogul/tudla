class Organizations::SettingsController < ApplicationController
  include OrganizationHierarchyFindable

  before_action :set_organization
  before_action :authorize_admin

  def show
  end
end
