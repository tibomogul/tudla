module PitchesHelper
  def pitch_badge_color(status)
    { "draft" => "badge-neutral", "ready_for_betting" => "badge-info",
     "bet" => "badge-success", "rejected" => "badge-error" }[status.to_s] || "badge-neutral"
  end

  def pitch_button_color(status)
    { "ready_for_betting" => "btn-info", "bet" => "btn-success",
     "rejected" => "btn-error" }[status.to_s] || "btn-neutral"
  end
end
