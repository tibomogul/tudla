class TasksController < ApplicationController
  include ActionView::RecordIdentifier
  include DashboardLists
  before_action :set_task, only: %i[ show edit update destroy update_state history move_to_today move_to_backlog ]

  # GET /tasks or /tasks.json
  def index
    @tasks = policy_scope(Task)
  end

  # GET /tasks/1 or /tasks/1.json
  def show
    if turbo_frame_request?
      render partial: "details", locals: { task: @task }
    end
  end

  # GET /tasks/new
  def new
    @task = Task.new
    set_users_selection
  end

  # GET /tasks/1/edit
  def edit
    set_users_selection
  end

  # POST /tasks or /tasks.json
  def create
    @task = Task.new(task_params)
    authorize @task

    respond_to do |format|
      if @task.save
        format.turbo_stream
        format.html { redirect_to @task, notice: "Task was successfully created." }
        format.json { render :show, status: :created, location: @task }
      else
        format.turbo_stream {
          render turbo_stream: turbo_stream.replace(
            dom_id(@task.scope, :new_task_form),
            partial: "tasks/quick_add_form",
            locals: { scope: @task.scope, project: @task.project, task: @task }
          ), status: :unprocessable_entity
        }
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @task.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /tasks/1 or /tasks/1.json
  def update
    authorize @task
    update_context = params[:task]&.dig(:update_context) || params[:update_context] || "details"
    
    respond_to do |format|
      if @task.update(task_params)
        format.turbo_stream do
          if update_context == "scope_list_item"
            render turbo_stream: turbo_stream.replace(dom_id(@task), partial: "shared/task_list_item", locals: { task: @task, show_drag_handle: true, update_context: "scope_list_item" })
          elsif update_context == "list_item"
            render turbo_stream: turbo_stream.replace(dom_id(@task), partial: "shared/task_list_item", locals: { task: @task, update_context: "list_item" })
          else
            render turbo_stream: turbo_stream.replace(dom_id(@task), partial: "tasks/details", locals: { task: @task })
          end
        end
        format.html { redirect_to @task, notice: "Task was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @task }
      else
        format.turbo_stream do
          if update_context == "scope_list_item"
            render turbo_stream: turbo_stream.replace(dom_id(@task), partial: "shared/task_list_item", locals: { task: @task, show_drag_handle: true, update_context: "scope_list_item" }), status: :unprocessable_entity
          elsif update_context == "list_item"
            render turbo_stream: turbo_stream.replace(dom_id(@task), partial: "shared/task_list_item", locals: { task: @task, update_context: "list_item" }), status: :unprocessable_entity
          else
            render turbo_stream: turbo_stream.replace(dom_id(@task), partial: "tasks/details", locals: { task: @task }), status: :unprocessable_entity
          end
        end
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @task.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /tasks/1 or /tasks/1.json
  def destroy
    authorize @task
    @task.destroy

    respond_to do |format|
      format.html { redirect_to tasks_path, notice: "Task was successfully archived.", status: :see_other }
      format.json { head :no_content }
    end
  end

  # PATCH /tasks/1/update_state
  def update_state
    authorize @task, :update?
    new_state = params[:state].to_sym
    @update_context = params[:update_context] || "dashboard"

    if @task.state_machine.can_transition_to?(new_state)
      @task.state_machine.transition_to!(new_state, user_id: current_user.id)
      set_dashboard_lists if @update_context == "dashboard"
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @task, notice: "Task moved to #{new_state}." }
      end
    else
      redirect_to @task, alert: "Cannot transition to #{new_state}."
    end
  end

  # PATCH /tasks/1/move_to_today
  def move_to_today
    authorize @task, :update?
    target_position = params[:position].presence&.to_i

    Task.transaction do
      @task.update!(in_today: true)
      reposition_list!(current_user, true, @task.id, target_position)
    end

    set_dashboard_lists

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: user_root_path, notice: "Task moved to Today's List." }
    end
  end

  # PATCH /tasks/1/move_to_backlog
  def move_to_backlog
    authorize @task, :update?
    target_position = params[:position].presence&.to_i

    Task.transaction do
      @task.update!(in_today: false)
      reposition_list!(current_user, false, @task.id, target_position)
    end

    set_dashboard_lists

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: user_root_path, notice: "Task moved to Backlog." }
    end
  end

  # PATCH /tasks/reorder_today
  def reorder_today
    ids = Array(params[:ids]).map(&:to_i)
    tasks = policy_scope(Task).where(responsible_user_id: current_user.id, in_today: true, id: ids)

    Task.transaction do
      ids.each_with_index do |id, idx|
        next unless tasks_by_id = tasks.find { |t| t.id == id }
        tasks_by_id.update_column(:today_position, idx)
      end
    end

    head :ok
  end

  # PATCH /tasks/reorder_backlog
  def reorder_backlog
    ids = Array(params[:ids]).map(&:to_i)
    tasks = policy_scope(Task).where(responsible_user_id: current_user.id, in_today: false, id: ids)

    Task.transaction do
      ids.each_with_index do |id, idx|
        next unless tasks_by_id = tasks.find { |t| t.id == id }
        tasks_by_id.update_column(:backlog_position, idx)
      end
    end

    head :ok
  end

  # GET /tasks/1/history
  def history
    params.permit(:user_id, :period, :id)
    @users = User.order(:email)
    @filter_user_id = params[:user_id].presence
    @filter_period = params[:period].presence || "7"

    @transitions = @task.task_transitions.order(:sort_key)

    if @filter_user_id
      @transitions = @transitions.where("metadata ->> 'user_id' = ?", @filter_user_id)
    end

    if @filter_period != "all"
      days = @filter_period.to_i
      @transitions = @transitions.where("created_at >= ?", days.days.ago)
    end

    if turbo_frame_request?
      render partial: "history", locals: { task: @task, transitions: @transitions }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_task
      @task = policy_scope(Task).find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def task_params
      params.expect(task: [ :name, :description, :project_id, :scope_id, :responsible_user_id, :nice_to_have, :unassisted_estimate, :ai_assisted_estimate, :actual_manhours ])
    end

    def set_users_selection
      @team_members = if @task.project.present?
        UserPartyRole.where(party: @task.project.team).to_a.map(&:user)
      else
        []
      end
    end

    # Moves the given task_id within either today or backlog list for current_user.
    def reposition_list!(user, in_today_flag, task_id, target_position)
      scope = policy_scope(Task).where(responsible_user_id: user.id, in_today: in_today_flag)
      ordered_ids = scope.order(in_today_flag ? :today_position : :backlog_position).pluck(:id)
      ordered_ids.delete(task_id)
      if target_position && target_position >= 0 && target_position <= ordered_ids.length
        ordered_ids.insert(target_position, task_id)
      else
        ordered_ids << task_id
      end

      ordered_ids.each_with_index do |id, idx|
        if in_today_flag
          Task.where(id: id).update_all(today_position: idx)
        else
          Task.where(id: id).update_all(backlog_position: idx)
        end
      end
    end

    def set_dashboard_lists
      base = policy_scope(Task).where(responsible_user_id: current_user.id)
      lists = compute_dashboard_lists(base)
      @today_tasks = lists[:today]
      @backlog_tasks = lists[:backlog]
      @completed_today_tasks = lists[:completed_today]
    end
end
