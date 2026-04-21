module PolymorphicParentReadOnly
  extend ActiveSupport::Concern

  private

  # Returns true when the polymorphic parent of `owner` (a Note/Link/Attachment)
  # is a Project/Scope/Task and that parent is currently read-only (done/archived).
  # Delegated-type proxies other than Project/Scope/Task do not have a lifecycle.
  def parent_read_only?(owner, child_assoc)
    record = resolve_polymorphic_parent(owner, child_assoc)
    return false unless record
    return false unless %w[Project Scope Task].include?(record.class.name)
    record.respond_to?(:read_only?) && record.read_only?
  end

  def resolve_polymorphic_parent(owner, child_assoc)
    proxy = owner.public_send(child_assoc)
    return nil unless proxy
    begin
      proxy.public_send(child_assoc)
    rescue NameError
      # Dev-mode class reloading can break the delegated-type accessor; fall back
      # to a manual constantize + find_by on the polymorphic columns.
      proxy.public_send("#{child_assoc}_type")&.constantize&.find_by(
        id: proxy.public_send("#{child_assoc}_id")
      )
    end
  end
end
