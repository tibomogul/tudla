class SubscribablesController < ApplicationController
  def create_subscription
    @subscribable = Pulse::Subscribable.find(params[:id])
    authorize @subscribable, :show?
    @subscription = Pulse::Subscription.create_or_find_by(user: current_user, subscribable: @subscribable)
    render turbo_stream: turbo_stream.replace("subscribable_subscription_#{@subscribable.id}",
      partial: "shared/subscribable_subscription",
      locals: { subscribable: @subscribable })
  end
end
