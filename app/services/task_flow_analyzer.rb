class TaskFlowAnalyzer
  Result = Struct.new(
    :state, :user, :avg, :min, :max, :median, :count, keyword_init: true)

  def initialize(scope = Task.all)
    @scope = scope
  end

  def state_durations
    transitions = TaskTransition
                    .where(task_id: @scope)
                    .order(:task_id, :sort_key)
                    .group_by(&:task_id)

    durations = Hash.new { |h, k| h[k] = [] }

    transitions.each_value do |list|
      list.each_cons(2) do |a, b|
        durations[a.to_state] << (b.created_at - a.created_at) if a.to_state
      end
    end

    durations.map do |state, arr|
      avg = arr.sum / arr.size if arr.any?
      Result.new(
        state: state,
        avg: avg,
        min: arr.min,
        max: arr.max,
        count: arr.size
      )
    end
  end

  def per_user_state_durations
    transitions = TaskTransition
                    .where(task_id: @scope)
                    .order(:task_id, :sort_key)
                    .group_by(&:task_id)

    durations = Hash.new { |h, k| h[k] = [] }

    transitions.each_value do |list|
      list.each_cons(2) do |a, b|
        user_id = a.metadata["user_id"] rescue nil
        next unless user_id

        key = [ user_id, a.to_state ]
        durations[key] << (b.created_at - a.created_at)
      end
    end

    results = []

    durations.each do |(user_id, state), arr|
      avg = arr.sum / arr.size if arr.any?
      results << Result.new(
        user: User.find_by(id: user_id),
        state: state,
        avg: avg,
        min: arr.min,
        max: arr.max,
        count: arr.size
      )
    end

    results
  end

  def per_user_cycle_times(start_state: "in_progress", end_state: "done")
    tasks = @scope.includes(:task_transitions)
    durations = Hash.new { |h, k| h[k] = [] }

    tasks.each do |task|
      transitions = task.task_transitions.order(:sort_key)
      start_t = transitions.find { |t| t.to_state == start_state }
      end_t   = transitions.find { |t| t.to_state == end_state }
      next unless start_t && end_t && end_t.created_at > start_t.created_at

      user_id = start_t.metadata["user_id"] rescue nil
      next unless user_id

      durations[user_id] << (end_t.created_at - start_t.created_at)
    end

    durations.map do |user_id, arr|
      avg = arr.sum / arr.size if arr.any?
      median = arr.sort[arr.size / 2] if arr.any?
      Result.new(
        user: User.find_by(id: user_id),
        avg: avg,
        median: median,
        min: arr.min,
        max: arr.max,
        count: arr.size
      )
    end
  end
end
