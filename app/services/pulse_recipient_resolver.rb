# Host-app recipient resolution for Pulse. Extends the default
# subscriber-based resolution with Tudla-specific rules that the extractable
# Pulse core must not know about (UserPartyRole, project admin semantics).
class PulseRecipientResolver < Pulse::RecipientResolver
  # When a task lands in review, the project's admins are notified even if
  # they never subscribed — this replaces the old commented-out
  # `notify_reviewers!` breadcrumb in TaskStateMachine.
  def call(event)
    recipients = super

    if event.action == "task.transitioned" && event.metadata["to_state"] == "in_review"
      recipients |= reviewer_users(event)
    end

    recipients
  end

  private

  def reviewer_users(event)
    task = event.subscribable.subscribable
    project = task.try(:project)
    return [] unless project

    User.active.joins(:user_party_roles)
        .where(user_party_roles: { party: project, role: "admin" })
        .to_a
  end
end
