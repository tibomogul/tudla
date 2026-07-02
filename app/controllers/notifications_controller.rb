class NotificationsController < ApplicationController
  def index
    authorize Pulse::Notification, :index?
    scoped = policy_scope(Pulse::Notification)
      .includes(event: { subscribable: :subscribable })
      .order(created_at: :desc)
    @pagy, @notifications = pagy(:offset, scoped, limit: 25)
  end

  # Clicking a notification both marks it read and navigates to its subject.
  def mark_read
    notification = policy_scope(Pulse::Notification).find(params[:id])
    authorize notification
    notification.mark_read!
    redirect_to subject_path_for(notification)
  end

  def mark_all_read
    authorize Pulse::Notification, :mark_all_read?
    policy_scope(Pulse::Notification).unread.update_all(read_at: Time.current)
    redirect_to notifications_path
  end

  private

  # The subject may have been deleted (metadata keeps the notification text
  # meaningful); fall back to the inbox rather than 500ing.
  def subject_path_for(notification)
    subject = notification.event.subscribable&.subscribable
    return notifications_path unless subject

    polymorphic_path(subject)
  rescue NoMethodError, ActionController::UrlGenerationError
    notifications_path
  end
end
