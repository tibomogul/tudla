class ProjectsController < ApplicationController
  include ActionView::RecordIdentifier
  before_action :set_project, only: %i[ show edit update destroy analytics_by_user cycle_time risk_history update_risk_state reorder_scopes ]

  # GET /projects or /projects.json
  def index
    @projects = policy_scope(Project)
  end

  # GET /projects/1 or /projects/1.json
  def show
    @dots = @project.scopes.map do |scope|
      {
        id: scope.id.to_s,
        color: "#ff6b6b",
        size: 8,
        position: scope.hill_chart_progress,
        description: scope.name
      }
    end
    analyzer = TaskFlowAnalyzer.new(@project.tasks)
    @results = analyzer.state_durations.sort_by(&:state)
    @subscribable = @project.subscribable
    @is_subscribed = @subscribable&.subscriptions&.where(user: current_user)&.exists? || false

    # Load recent reports for the project (last 20, ordered by as_of_at descending)
    @recent_reports = if @project.reportable
      policy_scope(@project.reports)
        .includes(:user)
        .order(as_of_at: :desc, created_at: :desc)
        .limit(20)
    else
      Report.none
    end

    if turbo_frame_request?
      render partial: "risk_details", locals: { project: @project }
    end
  end

  # GET /projects/new
  def new
    @project = Project.new
    authorize @project
    @allowed_teams = policy(@project).allowed_teams
  end

  # GET /projects/1/edit
  def edit
    @allowed_teams = policy(@project).allowed_teams
  end

  # POST /projects or /projects.json
  def create
    @project = Project.new(project_params)
    authorize @project

    # Validate that user can assign to this team
    if @project.team && !policy(@project).can_assign_to_team?(@project.team)
      @project.errors.add(:team_id, "You don't have permission to create projects for this team")
    end

    respond_to do |format|
      if @project.errors.empty? && @project.save
        format.html { redirect_to @project, notice: "Project was successfully created." }
        format.json { render :show, status: :created, location: @project }
      else
        @allowed_teams = policy(@project).allowed_teams
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /projects/1 or /projects/1.json
  def update
    # Validate team change if team_id is being updated
    if params[:project][:team_id].present?
      new_team = Team.find_by(id: params[:project][:team_id])
      if new_team && !policy(@project).can_assign_to_team?(new_team)
        @project.errors.add(:team_id, "You don't have permission to assign projects to this team")
      end
    end

    respond_to do |format|
      if @project.errors.empty? && @project.update(project_params)
        format.html { redirect_to @project, notice: "Project was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @project }
      else
        @allowed_teams = policy(@project).allowed_teams
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /projects/1 or /projects/1.json
  def destroy
    @project.destroy

    respond_to do |format|
      format.html { redirect_to projects_path, notice: "Project was successfully archived.", status: :see_other }
      format.json { head :no_content }
    end
  end

  # GET /projects/1/analytics_by_user
  def analytics_by_user
    analyzer = TaskFlowAnalyzer.new(@project.tasks)
    @results = analyzer.per_user_state_durations
                      .sort_by { |r| [ r.user&.email.to_s, r.state ] }
    @series = []
    @results
      .group_by { |r| r.user }
      .transform_keys { |user|
        user.email
      }
      .transform_values { |array_of_results|
        # array of averages per state
        array_of_results.map { |r| r.avg.to_f/3600 }
      }.each_pair { |k, v|
        @series << { name: k, data: v }
      }
    @labels = @results.group_by { |r| r.user }.values.first.map { |r| r.state.humanize }
  end

  # GET /projects/1/cycle_time
  def cycle_time
    analyzer = TaskFlowAnalyzer.new(@project.tasks)
    @results = analyzer.per_user_cycle_times.sort_by { |r| r.user&.email.to_s }
  end

  # PATCH /projects/1/update_risk_state
  def update_risk_state
    authorize @project, :update?
    new_state = params[:state].to_sym
    @update_context = params[:update_context] || "details"

    if @project.risk_state_machine.can_transition_to?(new_state)
      @project.risk_state_machine.transition_to!(new_state, user_id: current_user.id)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @project, notice: "Project risk moved to #{new_state}." }
      end
    else
      redirect_to @project, alert: "Cannot transition to #{new_state}."
    end
  end

  # GET /projects/1/risk_history
  def risk_history
    params.permit(:user_id, :period, :id)
    @users = User.order(:email)
    @filter_user_id = params[:user_id].presence
    @filter_period = params[:period].presence || "7"

    @transitions = @project.project_risk_transitions.order(:sort_key)

    if @filter_user_id
      @transitions = @transitions.where("metadata ->> 'user_id' = ?", @filter_user_id)
    end

    if @filter_period != "all"
      days = @filter_period.to_i
      @transitions = @transitions.where("created_at >= ?", days.days.ago)
    end

    if turbo_frame_request?
      render partial: "risk_history", locals: { project: @project, transitions: @transitions }
    end
  end

  # PATCH /projects/1/reorder_scopes
  def reorder_scopes
    authorize @project, :update?
    ids = Array(params[:ids]).map(&:to_i)
    scopes = policy_scope(Scope).where(project_id: @project.id, id: ids)

    Scope.transaction do
      ids.each_with_index do |id, idx|
        next unless scope = scopes.find { |s| s.id == id }
        scope.update_column(:project_position, idx)
      end
    end

    head :ok
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_project
      @project = Project.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def project_params
      params.expect(project: [ :name, :description, :team_id ])
    end
end
