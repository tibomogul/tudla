# frozen_string_literal: true

class ReportDraftService
  class DraftError < StandardError; end
  class NoActivityError < DraftError; end

  def initialize(report:, current_user:)
    @report = report
    @current_user = current_user
  end

  def no_activity?(activity_text)
    activity_text.blank? || activity_text.strip.start_with?("No changes found")
  end

  def generate
    raise DraftError, "LLM client not configured" unless defined?(LLM_CLIENT) && LLM_CLIENT

    activity_text = fetch_user_activity

    # If there is no recent activity, skip the LLM and let the caller
    # render a blank template with headers only.
    if no_activity?(activity_text)
      raise NoActivityError, "No recent activity found"
    end

    previous_report_text = fetch_previous_report
    template = load_doc("report_template.md")
    guide = load_doc("report_preparation_guide.md")

    prompt = build_prompt(activity_text, previous_report_text, template, guide)

    response = LLM_CLIENT.chat(
      messages: [
        {
          role: "system",
          content: "You are an assistant that writes concise, action-focused Dev Team Daily reports in markdown."
        },
        {
          role: "user",
          content: prompt
        }
      ]
    )

    response.completion
  rescue NoActivityError
    # Let NoActivityError bubble up so the controller can respond
    # with a blank template and notice.
    raise
  rescue StandardError => e
    Rails.logger.error("[ReportDraftService] Failed to generate draft: #{e.class}: #{e.message}")
    raise DraftError, e.message
  end

  # Fallback template with headers and blank sections when there is
  # no recent activity or the user cancels drafting.
  def blank_template
    <<~MD
      *My Vibe:*#{' '}

      *_Yesterday's Wins (Completed Tasks):_*
      * :white_check_mark: ``

      *_Today's Focus & Status:_*
      :large_green_circle: *_Main Focus_* ( )
      * :hammer: ``
      * :soon: ``

      *_Blockers / @Mentions:_*
      * :construction: ``
    MD
  end

  private

  attr_reader :report, :current_user

  def fetch_user_activity
    timezone = report.timezone
    now_in_tz = Time.current.in_time_zone(timezone)

    as_of = report.as_of_at&.in_time_zone(timezone) || now_in_tz

    previous = previous_report_record

    start_time, end_time = if previous&.as_of_at
      [ previous.as_of_at.in_time_zone(timezone), now_in_tz ]
    else
      if now_in_tz.monday?
        friday = now_in_tz.prev_occurring(:friday).in_time_zone(timezone)

        friday_end = friday.change(
          hour: as_of.hour,
          min:  as_of.min,
          sec:  as_of.sec
        )

        [ friday_end, now_in_tz ]
      else
        [ now_in_tz - 24.hours, now_in_tz ]
      end
    end

    Thread.current[:mcp_current_user] = current_user

    tool = ListUserChangesTool.new
    tool.call(
      start_time: start_time.iso8601,
      end_time: end_time.iso8601,
      limit: 200
    ).to_s
  ensure
    Thread.current[:mcp_current_user] = nil
  end

  def fetch_previous_report
    return "" unless report.reportable_id && current_user

    previous = previous_report_record

    previous&.content.to_s
  end

  def previous_report_record
    return nil unless report.reportable_id && current_user

    Report
      .where(user_id: current_user.id, reportable_id: report.reportable_id)
      .where(Report.arel_table[:as_of_at].lt(report.as_of_at || Time.current))
      .order(as_of_at: :desc)
      .first
  end

  def load_doc(filename)
    path = Rails.root.join("docs", filename)
    return "" unless File.exist?(path)

    File.read(path)
  end

  def build_prompt(activity_text, previous_report_text, template, guide)
    <<~PROMPT
      Prepare a Dev Team Daily status report in markdown.

      Follow this TEMPLATE exactly for structure, headings, and emoji usage:
      --- TEMPLATE START ---
      #{template}
      --- TEMPLATE END ---

      Use this GUIDE for how to think about the report, what to emphasize, and how to express risk and progress:
      --- GUIDE START ---
      #{guide}
      --- GUIDE END ---

      Here is my recent activity from the audit log (PaperTrail) for the relevant period:
      --- ACTIVITY START ---
      #{activity_text}
      --- ACTIVITY END ---

      Here is my previous report for additional context (if present):
      --- PREVIOUS REPORT START ---
      #{previous_report_text}
      --- PREVIOUS REPORT END ---

      Using all of the above, write a new Dev Team Daily report for me.
      - Use the TEMPLATE formatting and sections.
      - Use emojis as shown in the TEMPLATE and GUIDE.
      - Highlight yesterday's wins using completed work from ACTIVITY.
      - Propose today's focus and status based on in-progress work.
      - Call out any blockers you can infer.

      Output ONLY the final markdown report, with no explanation.
    PROMPT
  end
end
