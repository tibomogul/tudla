class SubscriptionPolicy < ApplicationPolicy
  # Subscribing = the right to watch = the right to see the underlying subject.
  def create?
    subject.present? && Pundit.policy!(user, subject).show?
  end

  def destroy?
    record.user_id == user.id
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(user: user)
    end
  end

  private

  def subject
    record.subscribable&.subscribable
  end
end
