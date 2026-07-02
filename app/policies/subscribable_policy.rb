class SubscribablePolicy < ApplicationPolicy
  # Visibility of a subscribable container follows its underlying subject.
  def show?
    subject.present? && Pundit.policy!(user, subject).show?
  end

  private

  def subject
    record.subscribable
  end
end
