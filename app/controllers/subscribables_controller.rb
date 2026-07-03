class SubscribablesController < ApplicationController
  def create_subscription
    @subscribable = Pulse::Subscribable.find(params[:id])
    authorize @subscribable, :show?
    # Publishable#subscribe is idempotent and returns the existing subscription
    # for an already-subscribed user (a bare create_or_find_by would return an
    # invalid record — the uniqueness validation fails before the DB fallback).
    @subscription = @subscribable.subscribable.subscribe(current_user)
    render turbo_stream: turbo_stream.replace("subscribable_subscription_#{@subscribable.id}",
      partial: "shared/subscribable_subscription",
      locals: { subscribable: @subscribable })
  end
end
