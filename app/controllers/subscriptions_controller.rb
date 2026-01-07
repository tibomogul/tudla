class SubscriptionsController < ApplicationController
  def destroy
    @subscription = Subscription.find(params[:id])
    @subscribable = @subscription.subscribable
    @subscription.destroy
    render turbo_stream: turbo_stream.replace("subscribable_subscription_#{@subscribable.id}",
      partial: "shared/subscribable_subscription",
      locals: { subscribable: @subscribable })
  end
end
