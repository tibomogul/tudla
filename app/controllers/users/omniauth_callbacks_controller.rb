# app/controllers/users/omniauth_callbacks_controller.rb:

class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  include Devise::Controllers::Rememberable

  skip_before_action :custom_authenticate_user!

  def google_oauth2
    handle_auth "Google"
  end

  def microsoft_graph
    handle_auth "Microsoft"
  end

  private

  def handle_auth(kind)
    Rails.logger.info "Processing #{kind} authentication callback"
    @user = User.from_omniauth(request.env["omniauth.auth"])

    if @user&.persisted?
      Rails.logger.info "#{@user.email} successfully logged in"
      flash[:notice] = I18n.t("devise.omniauth_callbacks.success", kind: kind) if is_navigational_format?
      begin
        remember_me @user
        sign_in_and_redirect @user, event: :authentication
      rescue => e
        Rails.logger.error "Error signing in user: #{e.message}"
        flash[:alert] = I18n.t("authentication.failure.user_not_found")
        redirect_to root_path
      end
    else
      # Useful for debugging login failures. Uncomment for development.
      # session['devise.google_data'] = request.env['omniauth.auth'].except('extra') # Removing extra as it can overflow some session stores
      reason = @user ? @user.errors.full_messages.join("\n") : I18n.t("authentication.failure.user_not_found")
      message = I18n.t("devise.omniauth_callbacks.failure",
        kind: kind,
        reason: reason)
      Rails.logger.error "#Log in failed: #{message}"
      flash[:alert] = message if is_navigational_format?
      redirect_to root_path
    end
  end
end
