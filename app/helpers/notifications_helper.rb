module NotificationsHelper
  # Event actions map 1:1 to i18n keys: "task.transitioned" →
  # t("pulse.events.task.transitioned"). Interpolations come from the event's
  # denormalized metadata so text renders even if the subject was deleted.
  def notification_text(notification)
    event = notification.event
    t("pulse.events.#{event.action}",
      actor: event.actor_name,
      subject: event.metadata["subject_name"],
      from_state: event.metadata["from_state"]&.humanize,
      to_state: event.metadata["to_state"]&.humanize,
      assignee: event.metadata["responsible_user_name"],
      default: t("pulse.events.fallback", actor: event.actor_name, action: event.action,
                                          subject: event.metadata["subject_name"]))
  end
end
