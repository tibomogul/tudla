class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :custom_authenticate_user!, unless: :devise_controller?
  before_action :configure_permitted_parameters, if: :devise_controller?
  after_action :broadcast_flash

  before_action :set_paper_trail_whodunnit

  include Pundit::Authorization
  include ActionView::RecordIdentifier
  include Pagy::Method

  protected

  def configure_permitted_parameters
    update_attrs = [ :password, :password_confirmation, :current_password ]
    devise_parameter_sanitizer.permit :account_update, keys: update_attrs
  end

  def custom_authenticate_user!
    redirect_to root_path, notice: "You must login" unless user_signed_in?
  end

  private

  def broadcast_flash
    return unless flash.any?
    return if response.redirect? # Let redirects handle flash normally

    turbo_stream = ApplicationController.render(
      partial: "application/flash",
      locals: { flash: flash.to_hash }
    )

    Turbo::StreamsChannel.broadcast_append_to "flash",
      target: "flash-container",
      html: turbo_stream

    flash.discard # prevent double rendering
  end
end
