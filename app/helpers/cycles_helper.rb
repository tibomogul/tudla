module CyclesHelper
  def cycle_badge_color(state)
    { "shaping" => "badge-info", "betting" => "badge-warning",
     "active" => "badge-success", "completed" => "badge-ghost" }[state.to_s] || "badge-ghost"
  end

  def cycle_button_color(state)
    { "betting" => "btn-warning", "active" => "btn-success",
     "completed" => "btn-neutral" }[state.to_s] || "btn-neutral"
  end
end
