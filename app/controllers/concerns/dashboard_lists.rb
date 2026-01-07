module DashboardLists
  extend ActiveSupport::Concern

  # Computes the three dashboard collections from a base tasks relation
  # Returns a hash with keys: :today, :backlog, :completed_today
  # The provided relation should already be policy-scoped and filtered to the current user
  def compute_dashboard_lists(tasks_relation)
    # Determine tasks whose most recent state is done
    done_ids = tasks_relation.joins(:task_transitions)
                             .merge(TaskTransition.where(most_recent: true, to_state: "done"))
                             .pluck(:id)
                             .uniq

    today = tasks_relation.where(in_today: true).where.not(id: done_ids).order(:today_position)
    backlog = tasks_relation.where(in_today: false).where.not(id: done_ids).order(:backlog_position)

    done_today_task_ids = TaskTransition
      .where(most_recent: true, to_state: "done")
      .where("created_at >= ?", Time.zone.now.beginning_of_day)
      .pluck(:task_id)
    completed_today = tasks_relation.where(id: done_today_task_ids, in_today: true).order(updated_at: :desc)

    { today: today, backlog: backlog, completed_today: completed_today }
  end
end
