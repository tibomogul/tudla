class SubscribablesController < ApplicationController
  def create_subscription
    @subscribable = Subscribable.find(params[:id])
    @subscription = @subscribable.subscriptions.create(user: current_user)
    render turbo_stream: turbo_stream.replace("subscribable_subscription_#{@subscribable.id}",
      partial: "shared/subscribable_subscription",
      locals: { subscribable: @subscribable })
  end
end
