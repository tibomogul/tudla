# frozen_string_literal: true

class Users::InvitationsController < Devise::InvitationsController
  protected

  def update_resource_params
    params.require(:user).permit(:preferred_name, :password, :password_confirmation, :invitation_token)
  end

  def after_accept_path_for(_resource)
    root_path
  end
end
