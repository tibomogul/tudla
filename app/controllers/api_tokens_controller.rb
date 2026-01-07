# frozen_string_literal: true

class ApiTokensController < ApplicationController
  before_action :custom_authenticate_user!
  before_action :set_api_token, only: [:destroy]

  def create
    @api_token = current_user.api_tokens.build(api_token_params)

    if @api_token.save
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.prepend("api_tokens_list", partial: "api_tokens/token_row", locals: { token: @api_token }),
            turbo_stream.update("token_modal", partial: "api_tokens/token_modal", locals: { token: @api_token.token })
          ]
        end
        format.html { redirect_to profile_path, notice: "API token created successfully. Token: #{@api_token.token}" }
      end
    else
      redirect_to profile_path, alert: "Failed to create API token: #{@api_token.errors.full_messages.join(', ')}"
    end
  end

  # Soft deletes and revokes the token
  # The token is marked as inactive (active=false) and soft-deleted (deleted_at set)
  # The revoke! method can still be called independently to revoke without deleting
  def destroy
    @api_token.destroy
    
    respond_to do |format|
      format.turbo_stream { 
        render turbo_stream: turbo_stream.remove(dom_id(@api_token))
      }
      format.html { redirect_to profile_path, notice: "API token was successfully archived." }
    end
  end

  private

  def set_api_token
    # Allow finding tokens that are already soft-deleted (for idempotent deletes)
    @api_token = current_user.api_tokens.with_deleted.find(params[:id])
  end

  def api_token_params
    params.require(:api_token).permit(:name, :expires_at)
  end
end
