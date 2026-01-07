module ProjectsHelper
  def risk_badge_color(state)
    {
      "green" => "badge-success",
      "yellow" => "badge-warning",
      "red" => "badge-error"
    }[state.to_s] || "badge-neutral"
  end

  def risk_button_color(state)
    {
      "green" => "btn-success",
      "yellow" => "btn-warning",
      "red" => "btn-error"
    }[state.to_s] || "btn-neutral"
  end
end
