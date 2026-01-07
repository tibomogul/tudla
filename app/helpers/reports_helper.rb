module ReportsHelper
  def report_status_badge(report)
    if report.submitted?
      content_tag(:span, "Submitted", class: "badge badge-success badge-sm")
    else
      content_tag(:span, "Draft", class: "badge badge-warning badge-sm")
    end
  end

  def reportable_name(report)
    return "Unknown" unless report.reportable&.reportable

    reportable = report.reportable.reportable
    "#{reportable.class.name}: #{reportable.name}"
  end
end
