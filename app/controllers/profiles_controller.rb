class ProfilesController < ApplicationController
  before_action :authenticate_user!

  def show
    @user = current_user
    # Only show non-deleted tokens (active scope includes deleted_at, active column, and expiry checks)
    @api_tokens = current_user.api_tokens.where(deleted_at: nil).order(created_at: :desc)
  end
end
