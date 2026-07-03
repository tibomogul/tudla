class NotificationsController < ApplicationController
  def index
    authorize Pulse::Notification, :index?
    scoped = policy_scope(Pulse::Notification)
    # The list only renders notification_text (event actor + metadata); the
    # subject itself is resolved per record in mark_read.
    @any_unread = scoped.unread.exists?
    @pagy, @notifications = pagy(:offset,
      scoped.includes(event: :user).order(created_at: :desc), limit: 25)
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
    # update_all fires no callbacks, so refresh the bell for other open tabs.
    Pulse::Notification.broadcast_indicator_for(current_user)
    redirect_to notifications_path
  end

  private

  # The subject may have been deleted (metadata keeps the notification text
  # meaningful); fall back to the inbox rather than 500ing.
  def subject_path_for(notification)
    subject = notification.event.subscribable&.subscribable
    return notifications_path unless subject
    # Soft-deleted subjects still generate valid URLs but their show actions
    # scope to .active and would 404.
    return notifications_path if subject.respond_to?(:deleted?) && subject.deleted?

    polymorphic_path(subject)
  rescue NoMethodError, ActionController::UrlGenerationError
    notifications_path
  end
end
