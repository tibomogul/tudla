class ScopesController < ApplicationController
  before_action :set_scope, only: %i[ show edit update destroy reorder_tasks ]

  # GET /scopes or /scopes.json
  def index
    @scopes = policy_scope(Scope)
  end

  # GET /scopes/1 or /scopes/1.json
  def show
    @dots = [
      {
        id: @scope.id.to_s,
        color: "#ff6b6b",
        size: 8,
        position: @scope.hill_chart_progress,
        description: @scope.name
      }
    ]
    @tasks = @scope.tasks.order(:scope_position, :id)
    analyzer = TaskFlowAnalyzer.new(@tasks)
    @results = analyzer.state_durations.sort_by(&:state)
  end

  # GET /scopes/new
  def new
    @scope = Scope.new
  end

  # GET /scopes/1/edit
  def edit
  end

  # POST /scopes or /scopes.json
  def create
    @scope = Scope.new(scope_params)
    authorize @scope

    respond_to do |format|
      if @scope.save
        format.turbo_stream
        format.html { redirect_to @scope, notice: "Scope was successfully created." }
        format.json { render :show, status: :created, location: @scope }
      else
        format.turbo_stream {
          render turbo_stream: turbo_stream.replace(
            dom_id(@scope.project, :new_scope_form),
            partial: "scopes/quick_add_form",
            locals: { project: @scope.project, scope: @scope }
          ), status: :unprocessable_entity
        }
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @scope.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /scopes/1 or /scopes/1.json
  def update
    respond_to do |format|
      if @scope.update(scope_params)
        format.html { redirect_to @scope, notice: "Scope was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @scope }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @scope.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /scopes/1 or /scopes/1.json
  def destroy
    @scope.destroy

    respond_to do |format|
      format.html { redirect_to scopes_path, notice: "Scope was successfully archived.", status: :see_other }
      format.json { head :no_content }
    end
  end

  # PATCH /scopes/1/reorder_tasks
  def reorder_tasks
    authorize @scope, :update?
    ids = Array(params[:ids]).map(&:to_i)
    tasks = policy_scope(Task).where(scope_id: @scope.id, id: ids)

    Task.transaction do
      ids.each_with_index do |id, idx|
        next unless task = tasks.find { |t| t.id == id }
        task.update_column(:scope_position, idx)
      end
    end

    head :ok
  end

  # POST /scopes/hillchart_update
  def hillchart_update
    @data = hillchart_params.to_h
    begin
      ActiveRecord::Base.transaction do
        @data[:hillchart_data][:positions].each do |task|
          scope = Scope.find(task[:id])
          scope.update!(hill_chart_progress: task[:new])
        end
      end
      render json: { status: :ok, location: @scope }
    rescue => e
      Rails.logger.error(e.message)
      render json: { errors: [ "Failed to update hill_chart_progress" ] }, status: :unprocessable_entity
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_scope
      @scope = policy_scope(Scope).find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def scope_params
      params.expect(scope: [ :name, :description, :project_id, :nice_to_have ])
    end

    def hillchart_params
      params.permit(hillchart_data: {}, scope: {})
    end
end
