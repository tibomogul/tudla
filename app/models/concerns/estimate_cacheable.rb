module EstimateCacheable
  extend ActiveSupport::Concern

  ESTIMATE_FIELDS = %w[unassisted_estimate ai_assisted_estimate actual_manhours].freeze

  included do
    after_commit :update_parent_estimate_caches, on: [ :create, :update ]
  end

  # Override SoftDeletable#destroy to also update caches
  # (update_column in soft_delete bypasses callbacks)
  def destroy(*)
    parent_scope = scope
    parent_project = project
    super
    self.class.recalculate_estimates_for(parent_scope) if parent_scope
    self.class.recalculate_estimates_for(parent_project) if parent_project
  end

  # Override SoftDeletable#restore to also update caches
  def restore(*)
    super
    self.class.recalculate_estimates_for(scope) if scope
    self.class.recalculate_estimates_for(project) if project
  end

  class_methods do
    def recalculate_estimates_for(record)
      return unless record
      return unless record.respond_to?(:cached_unassisted_estimate)

      table = record.class.table_name
      fk = record.class.name.foreign_key

      record.class.where(id: record.id).update_all(<<~SQL.squish)
        cached_unassisted_estimate = (SELECT COALESCE(SUM(unassisted_estimate), 0) FROM tasks WHERE tasks.#{fk} = #{table}.id AND tasks.deleted_at IS NULL),
        cached_ai_assisted_estimate = (SELECT COALESCE(SUM(ai_assisted_estimate), 0) FROM tasks WHERE tasks.#{fk} = #{table}.id AND tasks.deleted_at IS NULL),
        cached_actual_manhours = (SELECT COALESCE(SUM(actual_manhours), 0) FROM tasks WHERE tasks.#{fk} = #{table}.id AND tasks.deleted_at IS NULL)
      SQL
    end
  end

  private

  def update_parent_estimate_caches
    estimates_changed = (previous_changes.keys & ESTIMATE_FIELDS).any?
    scope_changed = previous_changes.key?("scope_id")
    project_changed = previous_changes.key?("project_id")
    is_new_record = previous_changes.key?("id")

    # Recalculate old parents if reassigned
    if scope_changed && !is_new_record
      old_scope_id = previous_changes["scope_id"][0]
      self.class.recalculate_estimates_for(Scope.find_by(id: old_scope_id)) if old_scope_id
    end

    if project_changed && !is_new_record
      old_project_id = previous_changes["project_id"][0]
      self.class.recalculate_estimates_for(Project.find_by(id: old_project_id)) if old_project_id
    end

    # Recalculate current parents if estimates changed, record created, or parent reassigned
    if estimates_changed || is_new_record || scope_changed || project_changed
      self.class.recalculate_estimates_for(scope) if scope
      self.class.recalculate_estimates_for(project) if project
    end
  end
end
