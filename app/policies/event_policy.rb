class EventPolicy < ApplicationPolicy
  # Events are only surfaced through notifications; visibility follows the
  # underlying subject of the subscribable they were published against.
  def show?
    subject.present? && Pundit.policy!(user, subject).show?
  end

  private

  def subject
    record.subscribable&.subscribable
  end
end
