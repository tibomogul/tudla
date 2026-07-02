class NotificationPolicy < ApplicationPolicy
  def index?
    true # list is scoped to the user's own notifications
  end

  def mark_read?
    record.user_id == user.id
  end

  # Authorized on the class; the controller operates on policy_scope only.
  def mark_all_read?
    user.present?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(user: user)
    end
  end
end
