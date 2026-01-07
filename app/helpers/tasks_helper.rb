module TasksHelper
  # TODO: unstyled
  def badge_color(state)
    {
      "new" => "badge-primary",
      "in_progress" => "badge-info",
      "in_review" => "badge-warning",
      "done" => "badge-success",
      "blocked" => "badge-error"
    }[state] || "badge-neutral"
  end

  def button_color(state)
    {
      "in_progress" => "btn-info",
      "in_review" => "btn-warning",
      "done" => "btn-success",
      "blocked" => "btn-error"
    }[state.to_s] || "btn-neutral"
  end
end
