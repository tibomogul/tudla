# frozen_string_literal: true

class Users::ConfirmationsController < Devise::ConfirmationsController
  skip_before_action :custom_authenticate_user!

  # GET /resource/confirmation?confirmation_token=abcdef
  # def show
  #   super
  # end

  # POST /resource/confirmation
  # def create
  #   super
  # end

  protected

  # The path used after confirmation.
  def after_confirmation_path_for(resource_name, resource)
    root_path
  end
end
