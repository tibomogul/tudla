class ReportsController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_report, only: %i[ show edit update destroy submit ]

  # GET /reports or /reports.json
  def index
    @reports = policy_scope(Report)
      .includes(:user, reportable: :reportable)
      .order(created_at: :desc)
  end

  # GET /reports/1 or /reports/1.json
  def show
  end

  # GET /reports/new
  def new
    @report = Report.new
    @report.user = current_user

    # Check if we have a reportable_id and reportable_type from params
    if params[:reportable_id] && params[:reportable_type]
      reportable = find_or_create_reportable(params[:reportable_type], params[:reportable_id])

      if reportable
        @report.reportable = reportable
        @report.as_of_at = calculate_as_of_at(reportable)
      end
    end

    # Default to current time in organization timezone
    @report.as_of_at ||= current_time_in_organization_timezone(@report)

    authorize @report
  end

  # POST /reports/prepare_draft
  def prepare_draft
    @report = Report.new(report_params)
    @report.user = current_user

    # Ensure as_of_at is set for window calculations
    @report.as_of_at ||= current_time_in_organization_timezone(@report)

    authorize @report, :create?

    service = ReportDraftService.new(report: @report, current_user: current_user)
    draft = service.generate

    respond_to do |format|
      format.json { render json: { content: draft } }
    end
  rescue ReportDraftService::NoActivityError => e
    respond_to do |format|
      format.json do
        render json: {
          content: service.blank_template,
          notice: "No recent activity found for this period. We've provided a blank template for you to fill in."
        }
      end
    end
  rescue ReportDraftService::DraftError => e
    respond_to do |format|
      format.json { render json: { error: e.message }, status: :unprocessable_entity }
    end
  end

  # GET /reports/1/edit
  def edit
  end

  # POST /reports or /reports.json
  def create
    @report = Report.new(report_params)
    @report.user = current_user

    # Parse as_of_at in organization timezone
    parse_as_of_at_in_timezone(@report)

    authorize @report

    respond_to do |format|
      if @report.save
        format.html { redirect_to @report, notice: "Report was successfully created." }
        format.json { render :show, status: :created, location: @report }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @report.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /reports/1 or /reports/1.json
  def update
    # Temporarily assign params to parse timezone
    @report.assign_attributes(report_params)
    parse_as_of_at_in_timezone(@report)

    respond_to do |format|
      if @report.save
        format.html { redirect_to @report, notice: "Report was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @report }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @report.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /reports/1 or /reports/1.json
  def destroy
    @report.destroy

    respond_to do |format|
      format.html { redirect_to reports_path, notice: "Report was successfully archived.", status: :see_other }
      format.json { head :no_content }
    end
  end

  # POST /reports/1/submit
  def submit
    authorize @report

    respond_to do |format|
      if @report.update(submitted_at: Time.current)
        # Schedule Slack posting based on timing
        schedule_slack_posting(@report)

        format.html { redirect_to @report, notice: "Report was successfully submitted.", status: :see_other }
        format.json { render :show, status: :ok, location: @report }
      else
        format.html { redirect_to @report, alert: "Failed to submit report.", status: :unprocessable_entity }
        format.json { render json: @report.errors, status: :unprocessable_entity }
      end
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_report
    @report = Report.find(params.expect(:id))
    authorize @report
  end

  # Only allow a list of trusted parameters through.
  def report_params
    params.expect(report: [ :content, :as_of_at, :reportable_id ])
  end

  # Find or create a reportable for the given type and id
  def find_or_create_reportable(reportable_type, reportable_id)
    # First, try to find an existing reportable
    reportable = Reportable.find_by(
      reportable_type: reportable_type,
      reportable_id: reportable_id
    )

    # If not found, create it
    unless reportable
      # Verify the actual entity exists
      entity = reportable_type.constantize.find_by(id: reportable_id)
      return nil unless entity

      reportable = Reportable.create!(
        reportable_type: reportable_type,
        reportable_id: reportable_id
      )
    end

    reportable
  end

  # Calculate as_of_at based on report requirement or current time in organization timezone
  def calculate_as_of_at(reportable)
    # Get organization timezone
    organization = get_organization_from_reportable(reportable)
    timezone = organization&.timezone || "Australia/Brisbane"
    current_time_in_tz = Time.current.in_time_zone(timezone)

    # Find the most recent report requirement for this reportable
    requirement = ReportRequirement
      .where(reportable: reportable)
      .order(created_at: :desc)
      .first

    if requirement
      # Get the next occurrence from the schedule (in organization timezone)
      requirement.next_occurrence(current_time_in_tz)
    else
      current_time_in_tz
    end
  end

  # Get organization from reportable (works for Project or Team)
  def get_organization_from_reportable(reportable)
    return nil unless reportable&.reportable

    case reportable.reportable.class.name
    when "Project"
      reportable.reportable.team&.organization
    when "Team"
      reportable.reportable.organization
    else
      nil
    end
  end

  # Get current time in the organization's timezone
  def current_time_in_organization_timezone(report)
    return Time.current unless report.reportable

    organization = get_organization_from_reportable(report.reportable)
    timezone = organization&.timezone || "Australia/Brisbane"
    Time.current.in_time_zone(timezone)
  end

  # Parse as_of_at datetime in organization timezone
  # The datetime_local_field sends datetime without timezone info,
  # so we need to interpret it as being in the organization's timezone
  def parse_as_of_at_in_timezone(report)
    return unless report.as_of_at_changed? && report.as_of_at.present?
    return unless report.reportable

    organization = get_organization_from_reportable(report.reportable)
    timezone_name = organization&.timezone || "Australia/Brisbane"

    # The as_of_at value from the form is parsed by Rails (usually as UTC or app default timezone)
    # We need to interpret those date/time components as being in the organization's timezone
    # Best practice: use ActiveSupport::TimeZone to parse in the correct timezone
    local_time = report.as_of_at
    tz = ActiveSupport::TimeZone[timezone_name]
    report.as_of_at = tz.parse(local_time.strftime("%Y-%m-%d %H:%M:%S"))
  end

  # Schedule Slack posting based on report timing
  # Posts immediately if submitted after as_of_date, or schedules for as_of_date if before
  def schedule_slack_posting(report)
    return unless report.as_of_at.present?

    # Determine when to post
    if report.submitted_at >= report.as_of_at
      # Submitted after as_of_date - post immediately
      PostReportToSlackJob.perform_later(report.id)
      Rails.logger.info("[ReportsController] Scheduled immediate Slack posting for report ##{report.id}")
    else
      # Submitted before as_of_date - schedule for as_of_date
      PostReportToSlackJob.set(wait_until: report.as_of_at).perform_later(report.id)
      Rails.logger.info("[ReportsController] Scheduled Slack posting for report ##{report.id} at #{report.as_of_at}")
    end
  end
end
