module PitchesHelper
  def pitch_badge_color(status)
    { "draft" => "badge-ghost", "ready_for_betting" => "badge-info",
     "bet" => "badge-success", "rejected" => "badge-error" }[status.to_s] || "badge-ghost"
  end

  def pitch_button_color(status)
    { "ready_for_betting" => "btn-info", "bet" => "btn-success",
     "rejected" => "btn-error" }[status.to_s] || "btn-neutral"
  end

  def pitch_appetite_badge_class(pitch)
    case pitch.appetite_batch
    when :big then "badge-primary"
    when :medium then "badge-accent"
    else "badge-secondary"
    end
  end

  def pitch_ingredients_count(pitch)
    [ pitch.problem, pitch.appetite, pitch.solution, pitch.rabbit_holes, pitch.no_gos ]
      .count(&:present?)
  end
end
