class SubscriptionsController < ApplicationController
  def destroy
    @subscription = Pulse::Subscription.find(params[:id])
    authorize @subscription
    @subscribable = @subscription.subscribable
    @subscription.destroy
    render turbo_stream: turbo_stream.replace("subscribable_subscription_#{@subscribable.id}",
      partial: "shared/subscribable_subscription",
      locals: { subscribable: @subscribable })
  end
end
